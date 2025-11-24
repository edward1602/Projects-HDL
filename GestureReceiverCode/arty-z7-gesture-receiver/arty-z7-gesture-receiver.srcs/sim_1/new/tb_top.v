`timescale 1ns / 1ps

module tb_top;

    // --- Tín hi?u ??u vào cho DUT ---
    reg         clk;
    reg         rst_n;
    reg         nrf_miso;
    reg         nrf_irq_n;
    
    // --- Tín hi?u ??u ra t? DUT ---
    wire        nrf_mosi;
    wire        nrf_sck;
    wire        nrf_csn;
    wire        nrf_ce;
    wire [47:0] data_received;
    wire        data_valid;

    // --- Kh?i t?o DUT (Device Under Test) ---
    top dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .nrf_miso       (nrf_miso),
        .nrf_irq_n      (nrf_irq_n),
        .nrf_mosi       (nrf_mosi),
        .nrf_sck        (nrf_sck),
        .nrf_csn        (nrf_csn),
        .nrf_ce         (nrf_ce),
        .data_received  (data_received),
        .data_valid     (data_valid)
    );

    // --- Bi?n mô ph?ng nRF24L01 ---
    reg [7:0] nrf_registers [0:31];    // M?ng thanh ghi gi? l?p
    reg [7:0] rx_fifo [0:5];           // FIFO ch?a 6 bytes payload
    reg [7:0] spi_rx_byte;             // Byte nh?n ???c t? MOSI
    reg [7:0] spi_tx_byte;             // Byte s? tr? v? qua MISO
    integer   bit_index;               // ??m bit trong SPI transaction
    reg       spi_active;              // ?ánh d?u ?ang trong SPI transaction
    reg [7:0] current_command;         // L?u l?nh hi?n t?i
    integer   payload_byte_count;      // ??m byte payload ?ang truy?n

    // --- T?o clock 50MHz (chu k? 20ns) ---
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    // --- Kh?i t?o giá tr? ban ??u ---
    initial begin
        // Kh?i t?o tín hi?u
        rst_n = 0;
        nrf_miso = 1'b0;
        nrf_irq_n = 1'b1;  // IRQ idle ? m?c cao (active low)
        
        // Kh?i t?o thanh ghi gi? l?p nRF24L01
        for (integer i = 0; i < 32; i = i + 1) begin
            nrf_registers[i] = 8'h00;
        end
        nrf_registers[7] = 8'h0E;  // STATUS register initial value
        
        // Kh?i t?o payload test (6 bytes: 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF)
        rx_fifo[0] = 8'hAA;
        rx_fifo[1] = 8'hBB;
        rx_fifo[2] = 8'hCC;
        rx_fifo[3] = 8'hDD;
        rx_fifo[4] = 8'hEE;
        rx_fifo[5] = 8'hFF;
        
        spi_active = 0;
        bit_index = 0;
        payload_byte_count = 0;
        
        // Dump waveform
        $dumpfile("tb_top.vcd");
        $dumpvars(0, tb_top);
        
        // Reset h? th?ng
        #100;
        rst_n = 1;
        $display("[%0t] Reset released, system starting...", $time);
        
        // Ch? h? th?ng kh?i t?o (c?u hình nRF24L01)
        #200000;  // Ch? ~200us cho quá trình init
        
        // Kích ho?t IRQ ?? báo có d? li?u (simulate data arrival)
        $display("[%0t] Simulating data arrival - Pulling IRQ low", $time);
        nrf_irq_n = 1'b0;
        
        // Ch? ??c xong payload
        wait(data_valid == 1'b1);
        #40;
        $display("[%0t] *** DATA RECEIVED ***", $time);
        $display("    Payload = 0x%012X", data_received);
        $display("    Expected: 0xAABBCCDDEEFF");
        
        if (data_received == 48'hAABBCCDDEEFF)
            $display("    >>> TEST PASSED! <<<");
        else
            $display("    >>> TEST FAILED! <<<");
        
        // Th? IRQ lên cao sau khi clear
        #1000;
        nrf_irq_n = 1'b1;
        
        // Test thêm 1 gói n?a v?i d? li?u khác
        #50000;
        $display("\n[%0t] Sending second packet...", $time);
        rx_fifo[0] = 8'h11;
        rx_fifo[1] = 8'h22;
        rx_fifo[2] = 8'h33;
        rx_fifo[3] = 8'h44;
        rx_fifo[4] = 8'h55;
        rx_fifo[5] = 8'h66;
        nrf_irq_n = 1'b0;
        
        wait(data_valid == 1'b1);
        #40;
        $display("[%0t] *** SECOND DATA RECEIVED ***", $time);
        $display("    Payload = 0x%012X", data_received);
        $display("    Expected: 0x112233445566");
        
        if (data_received == 48'h112233445566)
            $display("    >>> TEST PASSED! <<<");
        else
            $display("    >>> TEST FAILED! <<<");
        
        #10000;
        $display("\n[%0t] Simulation completed", $time);
        $finish;
    end

    // --- Mô ph?ng hành vi SPI Slave c?a nRF24L01 ---
    // Detect b?t ??u SPI transaction (CSN falling edge)
    always @(negedge nrf_csn) begin
        if (!spi_active) begin
            spi_active = 1;
            bit_index = 0;
            spi_rx_byte = 8'h00;
            payload_byte_count = 0;
            $display("[%0t] SPI Transaction START (CSN Low)", $time);
        end
    end

    // Detect k?t thúc SPI transaction (CSN rising edge)
    always @(posedge nrf_csn) begin
        if (spi_active) begin
            spi_active = 0;
            $display("[%0t] SPI Transaction END (CSN High)", $time);
        end
    end

    // X? lý SPI trên m?i c?nh lên c?a SCK
    always @(posedge nrf_sck) begin
        if (spi_active && !nrf_csn) begin
            // Nh?n bit t? MOSI (Master -> Slave)
            spi_rx_byte = {spi_rx_byte[6:0], nrf_mosi};
            bit_index = bit_index + 1;
            
            // Khi nh?n ?? 8 bit
            if (bit_index == 8) begin
                bit_index = 0;
                
                // Byte ??u tiên là command
                if (payload_byte_count == 0) begin
                    current_command = spi_rx_byte;
                    $display("[%0t]   Received Command: 0x%02X", $time, spi_rx_byte);
                    
                    // Chu?n b? byte tr? v? (STATUS register cho byte ??u)
                    spi_tx_byte = nrf_registers[7]; // STATUS
                    
                    // X? lý command
                    if ((spi_rx_byte & 8'hE0) == 8'h20) begin
                        // Write Register
                        $display("[%0t]   -> Write Register to addr 0x%02X", $time, spi_rx_byte & 8'h1F);
                    end else if (spi_rx_byte == 8'h61) begin
                        // Read RX Payload
                        $display("[%0t]   -> Read RX Payload", $time);
                        // Byte ti?p theo s? là payload[0]
                    end
                    
                end else begin
                    // Các byte ti?p theo là data
                    
                    // X? lý Write Register
                    if ((current_command & 8'hE0) == 8'h20) begin
                        integer addr;
                        addr = current_command & 8'h1F;
                        nrf_registers[addr] = spi_rx_byte;
                        $display("[%0t]   Write: Reg[0x%02X] = 0x%02X", $time, addr, spi_rx_byte);
                    end
                    
                    // Chu?n b? byte tr? v? ti?p theo
                    if (current_command == 8'h61) begin
                        // ?ang ??c payload, tr? v? byte t? FIFO
                        if (payload_byte_count <= 6) begin
                            spi_tx_byte = rx_fifo[payload_byte_count - 1];
                            $display("[%0t]   Sending payload[%0d] = 0x%02X", 
                                    $time, payload_byte_count-1, spi_tx_byte);
                        end
                    end else begin
                        spi_tx_byte = 8'h00;  // Dummy
                    end
                end
                
                payload_byte_count = payload_byte_count + 1;
                spi_rx_byte = 8'h00;
            end
        end
    end

    // G?i bit ra MISO trên c?nh xu?ng c?a SCK (SPI Mode 0)
    always @(negedge nrf_sck or negedge nrf_csn) begin
        if (!nrf_csn && spi_active) begin
            // Shift bit cao nh?t ra MISO
            nrf_miso <= spi_tx_byte[7];
            spi_tx_byte <= {spi_tx_byte[6:0], 1'b0};
        end
    end

    // Monitor các s? ki?n quan tr?ng
    always @(posedge data_valid) begin
        $display("\n========================================");
        $display("  DATA VALID PULSE DETECTED!");
        $display("  Received Payload: 0x%012X", data_received);
        $display("========================================\n");
    end

    // Timeout watchdog
    initial begin
        #5000000;  // 5ms timeout
        $display("\n!!! TIMEOUT - Test did not complete in time !!!");
        $finish;
    end

endmodule