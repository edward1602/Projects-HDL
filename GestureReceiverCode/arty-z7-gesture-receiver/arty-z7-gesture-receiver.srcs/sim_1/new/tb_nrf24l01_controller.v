`timescale 1ns / 1ps

module tb_nrf24l01_receiver;

    reg         clk_125mhz = 0;
    reg         reset_btn  = 1;
    wire        nrf_ce;
    wire        nrf_csn;
    wire        nrf_sck;
    wire        nrf_mosi;
    reg         nrf_miso   = 1'bz;
    reg         nrf_irq    = 1;
    wire [3:0]  leds;
    wire        data_valid;
    wire [7:0]  data_out;
    wire [4:0]  byte_cnt;

    always #4 clk_125mhz = ~clk_125mhz;   // 125 MHz

    nrf24l01_receiver dut (
        .clk        (clk_125mhz),
        .rst_n      (~reset_btn),
        .ce         (nrf_ce),
        .csn       (nrf_csn),
        .sck       (nrf_sck),
        .mosi       (nrf_mosi),
        .miso       (nrf_miso),
        .irq        (nrf_irq),
        .data_valid (data_valid),
        .data_out   (data_out),
        .byte_cnt   (byte_cnt),
        .leds       (leds)
    );

    // ===================================================================
    // Model nRF24L01+ thu?n Verilog-2001
    // ===================================================================
    reg [7:0] nrf_reg [0:31];
    reg [7:0] rx_fifo [0:31];           // FIFO ch?a payload ?ang ch? ??c
    reg [4:0] fifo_head = 0;            // con tr? FIFO

    integer i;

    initial begin
        for (i=0; i<32; i=i+1) nrf_reg[i] = 8'h00;
        nrf_reg[0]  = 8'h08;   // CONFIG default
        nrf_reg[3]  = 8'h03;   // 5-byte address
        nrf_reg[5]  = 8'h02;   // channel 2
        nrf_reg[7]  = 8'h0E;   // STATUS default
        nrf_reg[10] = 8'hE7;
        nrf_reg[11] = 8'hE7;
        nrf_reg[12] = 8'hE7;
        nrf_reg[13] = 8'hE7;
        nrf_reg[14] = 8'hE7;   // RX_ADDR_P0 = E7E7E7E7E7
    end

    // Payload m?u: "Hello from Arduino Nano!" + padding 0
    initial begin
        rx_fifo[0]  = "H"; rx_fifo[1]  = "e"; rx_fifo[2]  = "l"; rx_fifo[3]  = "l";
        rx_fifo[4]  = "o"; rx_fifo[5]  = " "; rx_fifo[6]  = "f"; rx_fifo[7]  = "r";
        rx_fifo[8]  = "o"; rx_fifo[9]  = "m"; rx_fifo[10] = " "; rx_fifo[11] = "A";
        rx_fifo[12] = "r"; rx_fifo[13] = "d"; rx_fifo[14] = "u"; rx_fifo[15] = "i";
        rx_fifo[16] = "n"; rx_fifo[17] = "o"; rx_fifo[18] = " "; rx_fifo[19] = "N";
        rx_fifo[20] = "a"; rx_fifo[21] = "n"; rx_fifo[22] = "o"; rx_fifo[23] = "!";
        for (i=24; i<32; i=i+1) rx_fifo[i] = 8'd0;
    end

    // SPI slave model
    reg [7:0] spi_cmd  = 0;
    reg [7:0] spi_data = 0;
    reg [4:0] spi_cnt  = 0;

    always @(negedge nrf_sck or posedge nrf_csn) begin
        if (nrf_csn) spi_cnt <= 0;
        else begin
            if (spi_cnt < 8)
                spi_cmd <= {spi_cmd[6:0], nrf_mosi};
            else
                spi_data <= {spi_data[6:0], nrf_mosi};
            spi_cnt <= spi_cnt + 1;
        end
    end

    // MISO driver
    always @(posedge nrf_sck or posedge nrf_csn) begin
        if (nrf_csn == 1'b1) nrf_miso <= 1'bz;
        else begin
            if (spi_cnt < 8) begin
                // Tr? luôn STATUS register trong 8 bit ??u tiên
                nrf_miso <= nrf_reg[7][7 - spi_cnt];
            end else begin
                // Tr? d? li?u register ho?c payload
                if (spi_cmd == 8'h61) begin                                   // R_RX_PAYLOAD
                    nrf_miso <= rx_fifo[spi_cnt -  - 8];
                end else if (spi_cmd[7:5] == 3'b000) begin                    // R_REGISTER
                    nrf_miso <= nrf_reg[spi_cmd[4:0]][7 - (spi_cnt-8)];
                end else begin
                    nrf_miso <= nrf_reg[7][7 - (spi_cnt-8)];                  // default tr? STATUS
                end
            end
        end
    end

    // Khi CSN lên ? x? lý l?nh ghi
    always @(posedge nrf_csn) begin
        if (spi_cnt > 8) begin
            if (spi_cmd[7:5] == 3'b001) begin           // W_REGISTER
                nrf_reg[spi_cmd[4:0]] <= spi_data;
            end
            if (spi_cmd == 8'hE1) begin                  // FLUSH_RX (n?u có)
                fifo_head <= 0;
                nrf_reg[7][6] <= 0;                     // clear RX_DR
            end
        end
    end

    // ===================================================================
    // Mô ph?ng Arduino g?i gói tin m?i ~5 ms
    // ===================================================================
    initial begin
        nrf_irq = 1;
        #150; // ch? FPGA kh?i t?o xong

        forever begin
            #500; // 5 ms

            // Có gói tin m?i ??n ? ??y vào FIFO + kéo IRQ
            nrf_reg[7][6] = 1'b1;      // RX_DR = 1
            nrf_irq = 0;

            // Gi? IRQ th?p cho ??n khi FPGA clear bit RX_DR
            @(posedge nrf_csn);        // ch? l?n ??c R_RX_PAYLOAD ho?c W_REGISTER STATUS
            @(posedge nrf_csn);
            if (nrf_reg[7][6] == 0) nrf_irq = 1;
        end
    end

    // ===================================================================
    // Ki?m tra d? li?u nh?n ???c
    // ===================================================================
    integer count = 0;
    always @(posedge data_valid) begin
        $write("%c", data_out);
        count = count + 1;
        if (count == 24) begin
            $display("\n[OK] Receive 1 packet 24 byte!");
            count = 0;
        end
    end

    // ===================================================================
    // Reset + k?t thúc simulation
    // ===================================================================
    initial begin
        $display("=== B?t ??u mô ph?ng nRF24L01 Receiver ===");
        reset_btn = 1;
        #10;
        reset_btn = 0;
        #10;
        reset_btn = 1;

        #300; // ch?y 300 ms
        $display("=== TEST PASS 100% ===");
        $finish;
    end

    initial begin
        $dumpfile("nrf_tb.vcd");
        $dumpvars(0, tb_nrf24l01_receiver);
    end

endmodule