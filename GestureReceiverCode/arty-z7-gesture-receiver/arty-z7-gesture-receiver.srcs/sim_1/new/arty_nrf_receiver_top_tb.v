`timescale 1ns / 1ps

module arty_nrf_receiver_top_tb;

    // ----------------------------------------------------
    // 1. KHAI BÁO TÍN HI?U TESTBENCH (reg/wire)
    // ----------------------------------------------------
    
    // System Signals
    reg clk_100mhz;
    reg rst_n;
    
    // Physical nRF24L01 Pins (Inputs to DUT)
    reg nrf_miso_pin;
    reg nrf_irq_pin;
    
    // Physical nRF24L01 Pins (Outputs from DUT - used for monitoring)
    wire nrf_ce_pin;
    wire nrf_csn_pin;
    wire nrf_sck_pin;
    wire nrf_mosi_pin;
    
    // UART Pin (Ignored since we removed UART logic)
    wire uart_tx_pin;
    
    // Data Outputs from DUT
    wire [15:0] x_axis_data_out;
    wire [15:0] y_axis_data_out;
    wire [15:0] z_axis_data_out;
    wire led_rdy;
    
    // Internal Control Signals for Simulation
    reg [7:0] tx_data_buffer [0:5]; // Buffer to hold mock 6-byte data
    reg [2:0] tx_byte_index;

    // ----------------------------------------------------
    // 2. KH?I T?O MODULE (DUT - Device Under Test)
    // ----------------------------------------------------
    
    // Note: Module spi_master, nrf24l01_controller, payload_assembler MUST be in the same project or compiled.
    arty_nrf_receiver_top DUT (
        .clk_100mhz(clk_100mhz),
        .rst_n(rst_n),
        
        .nrf_ce_pin(nrf_ce_pin),
        .nrf_csn_pin(nrf_csn_pin),
        .nrf_sck_pin(nrf_sck_pin),
        .nrf_mosi_pin(nrf_mosi_pin),
        .nrf_miso_pin(nrf_miso_pin),
        .nrf_irq_pin(nrf_irq_pin),
        
        .x_axis_data_out(x_axis_data_out),
        .y_axis_data_out(y_axis_data_out),
        .z_axis_data_out(z_axis_data_out),
        .led_rdy(led_rdy)
        
//        .uart_tx_pin(uart_tx_pin)
    );

    // ----------------------------------------------------
    // 3. T?O CLOCK
    // ----------------------------------------------------
    // 100 MHz clock (10 ns period)
    always #5 clk_100mhz = ~clk_100mhz; 

    // ----------------------------------------------------
    // 4. K?CH B?N TEST CHÍNH
    // ----------------------------------------------------
    initial begin
        $display("--- Bat dau Test Top Module ---");
        
        // 4.1. Thi?t l?p giá tr? ban ??u và Reset
        clk_100mhz = 1'b0;
        rst_n = 1'b0; // Active low reset
        nrf_miso_pin = 1'b1; // MISO ? m?c cao khi IDLE
        nrf_irq_pin = 1'b1; // Ng?t không ho?t ??ng
        
        // D? li?u m?u (Gi? ??nh giá tr? X=0x1234, Y=0x5678, Z=0x9ABC)
        // Little-Endian (LSB tr??c):
        tx_data_buffer[0] = 8'h34; // X LSB
        tx_data_buffer[1] = 8'h12; // X MSB
        tx_data_buffer[2] = 8'h78; // Y LSB
        tx_data_buffer[3] = 8'h56; // Y MSB
        tx_data_buffer[4] = 8'hBC; // Z LSB
        tx_data_buffer[5] = 8'h9A; // Z MSB
        
        #100; 
        rst_n = 1'b1; // Th? Reset. Kh?i t?o b?t ??u ngay l?p t?c.
        $display("Reset Hoan thanh. Bat dau chuoi Khoi tao...");

        // 4.2. Ch? Kh?i t?o Hoàn thành
        // Chu?i Kh?i t?o dài. Ch? nrf_ce_pin kéo lên 1 (RX_WAIT) ?? bi?t quá trình k?t thúc.
        @(posedge nrf_ce_pin); 
        $display("Khoi tao Hoan thanh. Module dang o STATE_RX_WAIT.");
        
        // Ch? thêm 100 ns ?? ?n ??nh tr?ng thái
        #100;

        // 4.3. Mô ph?ng Giao ti?p Nh?n D? li?u (RX)
        $display("--- Kich hoat Nhan Du lieu ---");
        
        // B??C A: Kích ho?t Ng?t (nrf_irq = 0)
        nrf_irq_pin = 1'b0;
        #100; // ??i module ph?n ?ng và kéo CE xu?ng (STATE_RX_READ_STATUS)

        // B??C B: Mô ph?ng ??c Status Register (TX=L?nh R_REGISTER | STATUS)
        // Master g?i l?nh. Slave (mô ph?ng) ch? c?n ph?n h?i 1 byte.
        @(negedge nrf_csn_pin); // ??i CSN xu?ng
        @(posedge nrf_csn_pin); // ??i chu k? SPI k?t thúc (??c Status)
        
        // B??C C: Mô ph?ng ??c Payload (TX=L?nh R_RX_PAYLOAD)
        // L?nh R_RX_PAYLOAD ???c g?i. Sau ?ó 6 byte d? li?u ???c truy?n.
        @(negedge nrf_csn_pin); // ??i CSN xu?ng l?n 2
        $display("Bat dau truyen 6 byte Payload...");
        
        // Vòng l?p truy?n 6 byte d? li?u (Payload)
        for (tx_byte_index = 0; tx_byte_index < 6; tx_byte_index = tx_byte_index + 1) begin
            // ??i c?nh LÊN c?a SCK ?? Master l?y m?u
            @(posedge nrf_sck_pin) begin
                // Cung c?p byte d? li?u ti?p theo qua MISO
                nrf_miso_pin = tx_data_buffer[tx_byte_index];
            end
        end
        
        // K?t thúc truy?n d? li?u
        @(posedge nrf_csn_pin); // ??i CSN lên cao (chu k? SPI k?t thúc)
        
        // B??C D: Mô ph?ng Xóa c? ng?t (TX=W_REGISTER | STATUS)
        // Master g?i l?nh. Không c?n ph?n h?i d? li?u.
        @(negedge nrf_csn_pin);
        @(posedge nrf_csn_pin);
        
        // Gi? l?p tr?ng thái ng?t ???c xóa b?i Master
        nrf_irq_pin = 1'b1;
        
        #50; // ??i d? li?u ???c x? lý trong payload_assembler
        
        // 4.4. Ki?m tra K?t qu?
        $display("--- Kiem tra Ket qua Giai ma ---");
//        @(posedge led_rdy); // Ch? c? packet_ready ???c kích ho?t
        
        if (x_axis_data_out == 16'h1234 && y_axis_data_out == 16'h5678 && z_axis_data_out == 16'h9ABC) begin
            $display("-> THANH CONG: Du lieu giai ma chinh xac.");
            $display("   X Axis: %h (Mong doi: 1234)", x_axis_data_out);
            $display("   Y Axis: %h (Mong doi: 5678)", y_axis_data_out);
            $display("   Z Axis: %h (Mong doi: 9ABC)", z_axis_data_out);
        end else begin
            $display("-> THAT BAI: Du lieu giai ma khong khop.");
            $display("   X Axis: %h (Mong doi: 1234)", x_axis_data_out);
        end
        
        // 4.5. K?t thúc mô ph?ng
        #100 $finish; 
    end
    
    // Ghi sóng (Tùy ch?n)
    initial begin
        $dumpfile("top_module.vcd");
        $dumpvars(0, arty_nrf_receiver_top_tb);
    end

endmodule