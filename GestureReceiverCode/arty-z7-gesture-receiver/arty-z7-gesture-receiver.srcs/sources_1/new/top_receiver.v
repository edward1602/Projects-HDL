`timescale 1ns / 1ps

module nrf_receiver_system_top(
    input wire clk,             // System Clock (100MHz/125MHz)
    input wire reset_btn,       // System Reset (Active High - Mapped to BTN0)
    
    // --- Giao ti?p NRF24L01 (Physical Pins - Mapped to Arduino Headers) ---
    output wire nrf_sck,        // IO13/SCK
    output wire nrf_mosi,       // IO11/MOSI
    input  wire nrf_miso,       // IO12/MISO
    output wire nrf_ce,         // IO9/CE
    output wire nrf_csn,        // IO10/CSN
    input  wire nrf_irq,        // IO8/IRQ (Ch? n?i, nh?ng code dùng Polling)
    
    // --- Giao di?n Debug (LEDs) ---
    output wire [3:0] leds      // 4 ?èn LED trên board
);

    // ====================================================================
    // 1. Dây n?i n?i b? (Interconnect Wires)
    // ====================================================================
    
    // SPI Interconnects
    wire w_spi_start;
    wire [7:0] w_spi_tx;
    wire [7:0] w_spi_rx;
    wire w_spi_busy;

    // Payload Interconnects
    wire [7:0] w_p0, w_p1, w_p2, w_p3, w_p4, w_p5;
    wire w_data_ready;

    // Parser Outputs (D? li?u 16-bit cu?i cùng)
    wire [15:0] x_val, y_val, z_val;
    wire w_valid;

    // ====================================================================
    // 2. Các Module Con (Sub-modules)
    // ====================================================================

    // --- A. SPI MASTER (?ã fix l?i timing) ---
    spi_master #(.CLK_DIV(6)) spi_inst (
        .clk(clk),
        .reset(reset_btn),
        .start(w_spi_start),
        .data_tx(w_spi_tx),
        .data_rx(w_spi_rx),
        .busy(w_spi_busy),
        
        // N?i Master I/O ra c?ng v?t lý
        .sck(nrf_sck),
        .mosi(nrf_mosi),
        .miso(nrf_miso)
    );

    // --- B. NRF CONTROLLER (?ã fix l?i FSM Address và Timing) ---
    nrf24l01_controller #(
        .USE_IRQ(0),        // Polling mode
        .DATA_RATE("250K")
    ) ctrl_inst (
        .clk(clk),
        .reset(reset_btn),
        .nrf_irq(nrf_irq), 
        
        // Payload output
        .payload_0(w_p0), .payload_1(w_p1),
        .payload_2(w_p2), .payload_3(w_p3),
        .payload_4(w_p4), .payload_5(w_p5),
        .data_ready(w_data_ready),
        
        // SPI Interface (Bus n?i b?)
        .spi_start(w_spi_start),
        .spi_tx(w_spi_tx),
        .spi_rx(w_spi_rx),
        .spi_busy(w_spi_busy),
        
        // NRF Control
        .ce(nrf_ce),
        .csn(nrf_csn)
    );

    // --- C. DATA PARSER (Arduino Compatible) ---
    data_parser parser_inst (
        .clk(clk),
        .reset(reset_btn),
        .payload_0(w_p0), .payload_1(w_p1),
        .payload_2(w_p2), .payload_3(w_p3),
        .payload_4(w_p4), .payload_5(w_p5),
        .data_ready(w_data_ready),
        .accel_x(x_val),
        .accel_y(y_val),
        .accel_z(z_val),
        .valid(w_valid)
    );

    // ====================================================================
    // 3. Logic Debug & Hi?n th? LED
    // ====================================================================

    // --- Heartbeat Counter ---
    reg [26:0] heartbeat_cnt;
    always @(posedge clk) heartbeat_cnt <= heartbeat_cnt + 1;
    
    wire w_rx_dr_status = w_spi_rx[6];

    // --- Data Valid Toggle ---
    reg valid_toggle;
    always @(posedge clk) begin
        if (reset_btn) valid_toggle <= 0;
        else if (w_valid) valid_toggle <= ~valid_toggle;
    end

    // --- Gán LED ---
    // LED 0: Heartbeat (Nh?p nháy ~1Hz) -> Báo hi?u FPGA s?ng, Clock t?t.
    assign leds[0] = heartbeat_cnt[26];
//    assign leds[0] = w_rx_dr_status;
    
    // LED 1: RX Mode Indicator -> Sáng khi CE=1 (?ang l?ng nghe).
    assign leds[1] = nrf_ce;
    
    // LED 2: SPI Activity -> Sáng liên t?c (Do Polling).
    assign leds[2] = w_spi_busy;

    // LED 3: Data Received -> ??o tr?ng thái m?i khi nh?n ???c gói tin ?úng.
    assign leds[3] = valid_toggle;
//    assign leds[3] = w_spi_rx[6];

endmodule