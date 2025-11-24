`timescale 1ns / 1ps
module tb_nrf24l01_controller;
    // --- 1. Inputs to DUT (Device Under Test) ---
    reg clk;
    reg rst;
    reg [7:0] spi_data_out; // MISO (Gi? l?p d? li?u t? NRF g?i v? FPGA)
    reg spi_done;           // C? báo SPI Master ?ã truy?n xong 1 byte

    // --- 2. Outputs from DUT ---
    wire [3:0] leds_out;
    wire spi_start;
    wire [7:0] spi_data_in; // MOSI (L?nh FPGA g?i ?i)
    wire nrf_csn;
    wire nrf_ce;

    // --- 3. Instantiate the DUT ---
    // ??m b?o module nrf_driver c?a b?n có các port t??ng ?ng
    nrf24l01_controller uut (
        .clk(clk), 
        .rst(rst), 
        .leds_out(leds_out),
        .spi_start(spi_start), 
        .spi_data_in(spi_data_in),   // Driver g?i ?i (MOSI)
        .spi_data_out(spi_data_out), // Driver nh?n v? (MISO)
        .spi_done(spi_done),
        .nrf_csn(nrf_csn), 
        .nrf_ce(nrf_ce)
    );

    // --- 4. Clock Generation (125 MHz -> 8ns period) ---
    always #4 clk = ~clk;

    // --- 5. Simulation Logic ---
    initial begin
        // A. Kh?i t?o
        clk = 0;
        rst = 1;
        spi_done = 0;
        spi_data_out = 0; // MISO m?c ??nh th?p
        
        $display("=== START SIMULATION ===");
        
        // B. Reset h? th?ng
        #100;
        rst = 0;
        $display("System Reset Released");

        // C. Gi? l?p ph?n h?i cho quá trình C?u hình (Config Sequence)
        // Driver s? g?i nhi?u l?nh (Config AA, Channel, Payload...)
        // Ta ch? c?n gi? v? "SPI Done" sau m?i l?n driver yêu c?u
        
        repeat(12) begin // Gi? s? có kho?ng 6 thanh ghi * 2 b??c (Cmd + Val)
            wait_and_respond(8'h0E); // Tr? v? Status m?c ??nh (0x0E)
        end
        
        $display("--- Config Phase Done. Entering RX Mode ---");
        
        // ??i Driver b?t CE lên (Vào ch? ?? nh?n)
        wait(nrf_ce == 1);
        #2000; // ??i delay poll trong code driver

        // D. K?ch b?n 1: Poll Status nh?ng KHÔNG có d? li?u
        // Driver g?i l?nh ??c Status (0x07)
        // Ta tr? v? 0x0E (RX FIFO Empty)
        wait_and_respond(8'h0E); // Tr? status r?ng
        wait_and_respond(8'h00); // Dummy byte response
        
        #2000; // Driver ??i ti?p...

        // E. K?ch b?n 2: CÓ D? LI?U (Mô ph?ng X = 426 -> 0x01AA)
        $display("--- Simulating Incoming Packet (X=426) ---");
        
        // 1. Driver poll Status -> Ta tr? v? 0x4E (Bit 6 = 1: RX_DR)
        wait_and_respond(8'h0E); // G?i dummy status khi nh?n l?nh
        wait_and_respond(8'h4E); // Tr? giá tr? Status th?c t? có c? RX_DR

        // 2. Driver th?y c? RX_DR, s? g?i l?nh Read RX Payload (0x61)
        wait_and_respond(8'h0E); // Ph?n h?i cho l?nh 0x61 (Status)

        // 3. Driver g?i Dummy ?? ??c 6 byte d? li?u. Ta b?n d? li?u gi? vào MISO:
        // Byte 0: X_Low  = 0xAA (1010 1010) <- Quan tr?ng ?? test LED
        wait_and_respond(8'hAA); 
        
        // Byte 1: X_High = 0x01
        wait_and_respond(8'h01);
        
        // Byte 2: Y_Low  = 0x5E (350)
        wait_and_respond(8'h5E);
        
        // Byte 3: Y_High = 0x01
        wait_and_respond(8'h01);
        
        // Byte 4: Z_Low  = 0x88 (392)
        wait_and_respond(8'h88);
        
        // Byte 5: Z_High = 0x01
        wait_and_respond(8'h01);

        $display("--- Payload Sent. Checking LEDs ---");
        
        // 4. Driver s? x? lý và sáng ?èn, sau ?ó g?i l?nh Xóa c? ng?t (Clear IRQ)
        // Driver g?i Write Reg Status (0x27)
        wait_and_respond(8'h0E);
        // Driver g?i giá tr? 0x40
        wait_and_respond(8'h0E);
        
        #100;
        
        // --- 6. T? ??ng ki?m tra k?t qu? (Self-Checking) ---
        // V?i code hi?n th? 3 bit cao c?a Byte Th?p (0xAA -> 101)
        // leds[3] = 1, leds[2] = 0, leds[1] = 1
        if (leds_out[3] == 1 && leds_out[2] == 0 && leds_out[1] == 1) begin
            $display("PASSED: LEDs indicate correct pattern 101 for Low Byte 0xAA");
        end else begin
            $display("FAILED: LEDs are %b (Expected x101)", leds_out);
        end

        $finish;
    end

    // --- TASK: Gi? l?p ph?n h?i c?a module SPI Master ---
    // Task này ??i Driver kích ho?t spi_start, sau ?ó delay (mô ph?ng th?i gian truy?n),
    // gán d? li?u MISO và b?t c? done.
    task wait_and_respond;
        input [7:0] miso_val; // Giá tr? NRF mu?n g?i cho FPGA
        begin
            // 1. ??i l?nh b?t ??u t? Driver
            @(posedge spi_start);
            
            // In ra debug xem Driver ?ang g?i cái gì (MOSI)
            $display("Time %t: Driver sent MOSI: %h", $time, spi_data_in);

            // 2. Gi? l?p th?i gian truy?n SPI (ví d? 16 chu k? clock)
            // Trong th?c t? s? lâu h?n (do CLK_DIV), nh?ng mô ph?ng thì cho nhanh
            #100; 
            
            // 3. Gán d? li?u tr? v? trên MISO
            spi_data_out = miso_val;
            
            // 4. Báo xong
            spi_done = 1;
            #10; // Gi? xung done 1 chút
            spi_done = 0;
            
            // ??i driver h? c? start xu?ng (Handshake)
            wait(spi_start == 0);
        end
    endtask
    
endmodule