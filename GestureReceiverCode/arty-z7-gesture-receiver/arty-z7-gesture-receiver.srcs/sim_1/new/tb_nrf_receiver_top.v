`timescale 1ns / 1ps

module tb_nrf_receiver_top;

    // Inputs
    reg clk;
    reg reset;
    reg spi_miso; // S? ???c lái b?i NRF Fake

    // Outputs
    wire spi_sck;
    wire spi_mosi;
    wire nrf_ce;
    wire nrf_csn;
    wire [15:0] x_axis_raw;
    wire [15:0] y_axis_raw;
    wire [15:0] z_axis_raw;
    wire new_data_valid;

    // Signals for Fake NRF
    reg trigger_rx;
    reg [7:0] p0, p1, p2, p3, p4, p5;
    wire miso_from_fake;

    // Instantiate the Unit Under Test (UUT)
    nrf_receiver_top uut (
        .clk(clk), 
        .reset(reset), 
        .spi_sck(spi_sck), 
        .spi_mosi(spi_mosi), 
        .spi_miso(miso_from_fake), // K?t n?i v?i Fake Slave
        .nrf_ce(nrf_ce), 
        .nrf_csn(nrf_csn), 
        .x_axis_raw(x_axis_raw), 
        .y_axis_raw(y_axis_raw), 
        .z_axis_raw(z_axis_raw), 
        .new_data_valid(new_data_valid)
    );

    // Instantiate Fake NRF24L01
    fake_nrf fake_nrf (
        .sck(spi_sck),
        .mosi(spi_mosi),
        .miso(miso_from_fake),
        .csn(nrf_csn),
        .ce(nrf_ce),
        .p0_in(p0), .p1_in(p1), .p2_in(p2), .p3_in(p3), .p4_in(p4), .p5_in(p5),
        .trigger_rx_interrupt(trigger_rx)
    );

    // Clock generation (100MHz)
    always #5 clk = ~clk;

    initial begin
        // Initialize Inputs
        clk = 0;
        reset = 1;
        trigger_rx = 0;
        // Gi? l?p d? li?u: X=0x0102, Y=0x0304, Z=0x0506
        // L?u ý: Do b?n ch?a s?a l?i Endianness, k?t qu? ??u ra d? ki?n s? b? ??o byte.
        p0 = 8'h01; p1 = 8'h02; 
        p2 = 8'h03; p3 = 8'h04; 
        p4 = 8'h05; p5 = 8'h06;

        // Wait 100 ns for global reset to finish
        #100;
        reset = 0;
        $display("--- Simulation Start: Reset Deasserted ---");

        // 1. Ch? quá trình c?u hình (Init) hoàn t?t
        // Quá trình này m?t kho?ng vài ms trong th?c t?, nh?ng trong sim ta ch?
        // ??n khi CE lên m?c 1 (k?t thúc config, vào tr?ng thái IDLE/Listening)
        wait (nrf_ce == 1); 
        $display("--- Configuration Done (CE went High) ---");
        
        #20000; // Ch? thêm m?t chút ?? FSM ?n ??nh ? IDLE

        // 2. Gi? l?p nh?n gói tin t? không khí
        $display("--- Triggering Simulated Packet Reception ---");
        trigger_rx = 1;
        #20;
        trigger_rx = 0;

        // 3. Quan sát
        // Controller s? poll tr?ng thái -> th?y bit 6 = 1 -> ??c payload -> Output
        wait (new_data_valid == 1);
        
        $display("--- Data Received Valid Pulse Detected ---");
        $display("Expected Payload Bytes: 01 02 | 03 04 | 05 06");
        $display("Received Output (Hex): X=%h | Y=%h | Z=%h", x_axis_raw, y_axis_raw, z_axis_raw);
        
        // Ki?m tra k?t qu? (L?u ý l?i Endianness b?n ch?a s?a)
        // Hi?n t?i code b?n ghép: {payload_1, payload_0} -> {02, 01} = 0201
        if (x_axis_raw == 16'h0201 && y_axis_raw == 16'h0403 && z_axis_raw == 16'h0605) begin
            $display(">>> TEST PASS: Data flow is correct (NOTE: Bytes are swapped as expected due to pending fix).");
        end else begin
            $display(">>> TEST FAIL: Data mismatch.");
        end

        #5000;
        $stop;
    end
      
endmodule