`timescale 1ns / 1ps

module tb_top;

    // --- 1. Inputs ---
    reg clk;
    reg reset_btn;
    reg nrf_miso;
    reg nrf_irq;

    // --- 2. Outputs ---
    wire [3:0] leds;
    wire nrf_ce;
    wire nrf_csn;
    wire nrf_sck;
    wire nrf_mosi;
    
    // Wires debug
    wire [15:0] x_out;
    wire [15:0] y_out;
    wire [15:0] z_out;

    // Instantiate TOP
    top uut (
        .clk(clk),
        .reset_btn(reset_btn),
        .leds(leds),
        .nrf_ce(nrf_ce),
        .nrf_csn(nrf_csn),
        .nrf_sck(nrf_sck),
        .nrf_mosi(nrf_mosi),
        .nrf_miso(nrf_miso),
        .nrf_irq(nrf_irq)
    );
    
    assign x_out = uut.x_out;
    assign y_out = uut.y_out;
    assign z_out = uut.z_out;

    always #4 clk = ~clk;

    // --- TASK 1: SINGLE BYTE REPLY (Dùng cho Config & Polling) ---
    // Chip NRF th?t: Khi CSN xu?ng, nó g?i Status Byte, nh?n Command Byte, r?i CSN lên.
    task spi_slave_reply;
        input [7:0] status_response;
        integer i;
        begin
            wait(nrf_csn == 0);
            #1; nrf_miso = status_response[7]; // Setup bit ??u

            for (i = 7; i >= 0; i = i - 1) begin
                @(posedge nrf_sck); 
                @(negedge nrf_sck); 
                #1;
                if (i > 0) nrf_miso = status_response[i-1];
            end
            
            wait(nrf_csn == 1);
            #1; nrf_miso = 0;
        end
    endtask
    
    // --- TASK 2: BURST READ PAYLOAD (Dùng cho Data Read) ---
    // Chip NRF th?t: CSN xu?ng -> G?i Status -> G?i Data 0..5 -> CSN lên
    task spi_simulate_burst_read;
            input [7:0] status_byte;      // Byte ph?n h?i ??u tiên
            input [7:0] b0, b1, b2, b3, b4, b5; // 6 Byte d? li?u Payload
            reg [7:0] buffer [0:6];       // T?ng c?ng 7 byte
            integer k, bit_idx;
            begin
                // Chu?n b? d? li?u
                buffer[0] = status_byte; 
                buffer[1] = b0; buffer[2] = b1;
                buffer[3] = b2; buffer[4] = b3;
                buffer[5] = b4; buffer[6] = b5;
    
                // 1. Ch? b?t ??u transaction
                wait(nrf_csn == 0);
                
                // Setup bit ??u tiên c?a Byte 0 (Status) ngay l?p t?c
                #1; nrf_miso = buffer[0][7];
    
                // 2. Loop qua toàn b? 7 bytes liên t?c
                for (k = 0; k < 7; k = k + 1) begin
                    for (bit_idx = 7; bit_idx >= 0; bit_idx = bit_idx - 1) begin
                        @(posedge nrf_sck); // FPGA Sample
                        @(negedge nrf_sck); // FPGA Shift
                        
                        #1; // Delay timing an toàn
                        
                        // Logic l?y bit ti?p theo
                        if (bit_idx > 0) 
                            nrf_miso = buffer[k][bit_idx-1];
                        else if (k < 6) 
                            nrf_miso = buffer[k+1][7]; // Chuy?n sang bit 7 c?a byte k? ti?p
                    end
                end
                
                // 3. K?t thúc transaction
                wait(nrf_csn == 1);
                #1; nrf_miso = 0;
            end
        endtask

    // --- MAIN TEST ---
    localparam [15:0] X_EXP = 16'b0000000110101010; 
    localparam [15:0] Y_EXP = 16'b0000000101011110; 
    localparam [15:0] Z_EXP = 16'b1010101111001101; 

    initial begin
        clk = 0; reset_btn = 1; nrf_miso = 0; nrf_irq = 1;
        #100; reset_btn = 0;

        $display("START SIMULATION: Full Hardware Behavior Model");

        // B. Config Sequence (12 transactions)
        repeat(12) begin
            spi_slave_reply(8'b00001110); // Status 0x0E
            // L?u ý: Controller c?a b?n g?i 2 byte m?i l?n config (Cmd + Val)
            // spi_slave_reply ? ?ây x? lý t?ng CSN toggle m?t.
            // N?u controller b?n g?i Cmd -> CSN lên -> Val -> CSN lên, thì repeat(12) là ?úng.
        end
        
        $display("Config Done. Waiting for RX...");
        wait(nrf_ce == 1);

        // C. Data Ready Simulation
        // 1. Poll Status -> Tr? l?i Data Ready (0x4E)
        spi_slave_reply(8'b00001110); // Response cho Byte Command Read Status
        spi_slave_reply(8'b01001110); // Response giá tr? Status (0x4E)
        
        // 2. Read Payload (Burst 7 Bytes: 1 Status + 6 Data)
        $display("--- Sending Burst Payload ---");
        
        spi_simulate_burst_read(
            8'b00001110,            // Byte 0: Status
            8'b10101010, 8'b00000001, // X: 0xAA, 0x01
            8'b01011110, 8'b00000001, // Y: 0x5E, 0x01
            8'b11001101, 8'b10101011  // Z: 0xCD, 0xAB
        );

        // 3. Clear IRQ
        #200;
        spi_slave_reply(8'b00001110); 
        spi_slave_reply(8'b00001110);

        // D. Check
        if (x_out === X_EXP && y_out === Y_EXP && z_out === Z_EXP) begin
            $display("---------------------------------------------------");
            $display("PASSED: Simulation matches Hardware Behavior!");
            $display("RECEIVED: X=%h | Y=%h | Z=%h", x_out, y_out, z_out);
            $display("---------------------------------------------------");
        end else begin
            $display("---------------------------------------------------");
            $display("FAILED: Mismatch");
            $display("RECEIVED: X=%h | Y=%h | Z=%h", x_out, y_out, z_out);
            $display("EXPECTED: X=%h | Y=%h | Z=%h", X_EXP, Y_EXP, Z_EXP);
            $display("---------------------------------------------------");
        end
        
        $finish;
    end

endmodule