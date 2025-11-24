`timescale 1ns / 1ps

module nrf_receiver_system_top(
    input wire clk,           // H16 (125MHz)
    input wire reset_btn,     // D19
    output wire [3:0] leds,   // R14, P14, N16, M14
    
    // NRF24L01 ChipKit Header Pins (Theo file .xdc)
    output wire nrf_ce,       // V18
    output wire nrf_csn,      // T16
    output wire nrf_sck,      // N17
    output wire nrf_mosi,     // R17
    input  wire nrf_miso,     // P18
    input  wire nrf_irq       // V17
);

    wire spi_start, spi_done;
    wire [7:0] spi_din, spi_dout;
    wire rst = reset_btn;

    // Instantiate SPI Master
    spi_master spi_inst (
        .clk(clk),
        .rst(rst),
        .start(spi_start),
        .data_in(spi_din),
        .data_out(spi_dout),
        .done(spi_done),
        .sck(nrf_sck),
        .mosi(nrf_mosi),
        .miso(nrf_miso)
    );

    // Instantiate NRF Driver
    nrf24l01_controller ctrl_inst (
        .clk(clk),
        .rst(rst),
        .leds_out(leds),
        .spi_start(spi_start),
        .spi_data_in(spi_din),
        .spi_data_out(spi_dout),
        .spi_done(spi_done),
        .nrf_csn(nrf_csn),
        .nrf_ce(nrf_ce)
    );

endmodule