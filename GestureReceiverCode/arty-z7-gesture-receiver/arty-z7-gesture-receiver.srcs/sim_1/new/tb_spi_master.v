`timescale 1ns / 1ps

module tb_spi_master;

    // ----------------------------------------------------
    // #1. Khai báo Tham s? và H?ng s? (PARAMETER & CONSTANTS)
    // ----------------------------------------------------
    // Tham s? CLK_DIV ph?i kh?p v?i module DUT
    parameter CLK_DIV = 50; 
    
    // T?c ?? ??ng h? (CLK_PERIOD)
    parameter CLK_PERIOD = 10; // 10ns -> 100MHz clock
    
    // ??nh ngh?a d? li?u mà SLAVE s? "g?i" (Master s? nh?n)
    parameter SLAVE_TX_DATA = 8'hC3; // 11000011
    
    
    // ----------------------------------------------------
    // #2. Khai báo Tín hi?u (SIGNALS)
    // ----------------------------------------------------
    reg clk;
    reg reset;
    reg start;
    reg [7:0] data_tx;
    reg miso; // Master In Slave Out (Slave g?i)
    
    wire [7:0] data_rx;
    wire busy;
    wire sck;
    wire mosi; // Master Out Slave In (Master g?i)
    
    // Bi?n ??m (ph?i ???c khai báo ? ph?m vi module)
    integer bit_count;

    
    // ----------------------------------------------------
    // #3. Kh?i t?o Module D??i Th? Nghi?m (DUT - Device Under Test)
    // ----------------------------------------------------
    spi_master #(.CLK_DIV(CLK_DIV)) DUT (
        .clk(clk),
        .reset(reset),
        .start(start),
        .data_tx(data_tx),
        .data_rx(data_rx),
        .busy(busy),
        .sck(sck),
        .mosi(mosi),
        .miso(miso)
    );
    
    
    // ----------------------------------------------------
    // #4. T?o Clock
    // ----------------------------------------------------
    always begin
        # (CLK_PERIOD / 2) clk = ~clk;
    end
    
    
    // ----------------------------------------------------
    // #5. K?ch b?n mô ph?ng chính (Test Scenario)
    // ----------------------------------------------------
    initial begin
        // 1. Kh?i t?o giá tr? ban ??u
        clk = 0;
        reset = 1;
        start = 0;
        data_tx = 8'hAA; 
        miso = 0;
        
        $display("----------------------------------------");
        $display("B?t ??u mô ph?ng SPI Master");
        
        // 2. Thi?t l?p l?i h? th?ng
        @(posedge clk) #1;
        reset = 0;
        $display("[%0t] Thi?t l?p l?i (Reset) hoàn t?t.", $time);
        
        // 3. Chu?n b? d? li?u và b?t ??u truy?n
        @(posedge clk) #1;
        data_tx = 8'h55; // D? li?u G?i: 01010101
        start = 1;
        $display("[%0t] Kích ho?t Start. D? li?u TX = %h", $time, data_tx);
        
        @(posedge clk) #1;
        start = 0; // T?t Start sau 1 chu k? clock
        
        // Kh?i t?o b? ??m bit t?i ?ây
        bit_count = 0;
        
        // 4. Mô ph?ng ph?n h?i t? Slave (miso)
        // L?p qua 8 bit
        while (bit_count < 8) begin
            
            // Ch? ??i SCK lên (Master ??c d? li?u t? Slave trên c?nh lên c?a SCK)
            @(posedge sck) begin
                // SCK lên: Master ??c MISO
                #1; // Th?i gian tr? nh? ?? Master k?p ??c
                
                // Cung c?p bit ti?p theo t? Slave (MSB tr??c)
                miso = SLAVE_TX_DATA[7 - bit_count]; 
                
                $display("[%0t] SCK Lên. Bit #%0d. MISO (Slave G?i) = %b. MOSI (Master G?i) = %b", 
                         $time, bit_count, miso, mosi);
                
                bit_count = bit_count + 1;
            end
            
            // Ch? ??i SCK xu?ng, ch? ?? ??m b?o chu trình ho?t ??ng
            @(negedge sck) begin
                // Master ??t MOSI cho bit ti?p theo t?i ?ây (d?a trên thi?t k? DUT)
            end
        end
        
        // 5. Ch? module chuy?n sang tr?ng thái DONE (busy=0)
        @(posedge busy) #1; 
        @(negedge busy) #1;
        
        // 6. Ki?m tra k?t qu?
        $display("----------------------------------------");
        $display("[%0t] Truy?n hoàn t?t. Busy = %b, SCK = %b.", $time, busy, sck);
        $display("D? li?u TX (G?i): %h", data_tx);
        $display("D? li?u RX (Nh?n): %h", data_rx);
        
        if (data_rx === SLAVE_TX_DATA) begin
            $display("--- KI?M TRA: THÀNH CÔNG! D? li?u nh?n kh?p v?i d? li?u Slave gi? l?p (%h).", SLAVE_TX_DATA);
        end else begin
            $display("--- KI?M TRA: TH?T B?I! D? li?u nh?n (%h) không kh?p v?i d? li?u Slave gi? l?p (%h).", data_rx, SLAVE_TX_DATA);
        end
        $display("----------------------------------------");
        
        // 7. K?t thúc mô ph?ng
        #100 $finish;
    end
    
    // Ghi các tín hi?u ra file VCD ?? xem d?ng sóng
    initial begin
        $dumpfile("spi_master.vcd");
        $dumpvars(0, tb_spi_master);
    end

endmodule