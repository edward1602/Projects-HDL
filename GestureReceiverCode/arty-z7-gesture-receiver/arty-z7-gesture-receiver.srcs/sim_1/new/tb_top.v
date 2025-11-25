`timescale 1ns/1ps
module tb_top;
    reg         clk;
    reg         rst_n;
    reg         nrf_miso;
    reg         nrf_irq_n;
    wire        nrf_mosi;
    wire        nrf_sck;
    wire        nrf_csn;
    wire        nrf_ce;
    wire [47:0] data_received;
    wire        data_valid;

    top dut (
        .clk           (clk),
        .rst_n         (rst_n),
        .nrf_miso      (nrf_miso),
        .nrf_irq_n     (nrf_irq_n),
        .nrf_mosi      (nrf_mosi),
        .nrf_sck       (nrf_sck),
        .nrf_csn       (nrf_csn),
        .nrf_ce        (nrf_ce),
        .data_received (data_received),
        .data_valid    (data_valid)
    );

    // Clock 50MHz
    initial clk = 0;
    always #10 clk = ~clk;

    // Gi? l?p Arduino g?i 6 bytes: 0x11, 0x22, 0x33, 0x44, 0x55, 0x66
    reg [7:0] arduino_data [0:6];
    integer i;
    
    initial begin
//        $dumpfile("wave.vcd");
//        $dumpvars(0, tb_top);
        
        // Data t? Arduino
        arduino_data[0] = 8'h00;  // STATUS byte (b? qua)
        arduino_data[1] = 8'h11;  // Byte 1
        arduino_data[2] = 8'h22;  // Byte 2
        arduino_data[3] = 8'h33;  // Byte 3
        arduino_data[4] = 8'h44;  // Byte 4
        arduino_data[5] = 8'h55;  // Byte 5
        arduino_data[6] = 8'h66;  // Byte 6
        
        // Reset
        rst_n = 0;
        nrf_irq_n = 1;
        nrf_miso = 0;
        #100;
        rst_n = 1;
        
        $display("=== FPGA starting ===");
        
        // Ch? FPGA vào ch? ?? nh?n (CE = 1)
        wait(nrf_ce == 1);
        $display("[%0t] FPGA ready for data", $time);
        
        // Gi? l?p Arduino g?i data (kéo IRQ xu?ng)
        #1000;
        $display("[%0t] Arduino sends data -> IRQ = 0", $time);
        nrf_irq_n = 0;
        
        // Ch? FPGA ??c (CSN = 0)
        wait(nrf_csn == 0);
        $display("[%0t] FPGA is reading", $time);
        
        // G?i 7 bytes qua SPI
        for (i = 0; i < 7; i = i + 1) begin
            wait(nrf_sck == 1);  // ??i SCK lên
            repeat(8) begin
                @(posedge nrf_sck);
                #2 nrf_miso = arduino_data[i][7];
                arduino_data[i] = {arduino_data[i][6:0], 1'b0};
            end
        end
        
        // Ch? k?t qu?
        wait(data_valid == 1);
        $display("\n*** DATA ***");
        $display("Data = 0x%012X", data_received);
        $display("Expected: 0x112233445566");
        
        if (data_received == 48'h112233445566)
            $display(">>> PASS <<<\n");
        else
            $display(">>> FAIL <<<\n");
        
        #1000;
        $finish;
    end
    
    // Timeout
    initial begin
        #500000;
        $display("TIMEOUT!");
        $finish;
    end
endmodule