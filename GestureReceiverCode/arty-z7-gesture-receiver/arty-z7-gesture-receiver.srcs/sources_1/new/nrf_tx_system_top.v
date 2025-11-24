`timescale 1ns / 1ps

module nrf_tx_system_top(
    input wire clk,
    input wire reset_btn,
    
    output wire nrf_sck,
    output wire nrf_mosi,
    input  wire nrf_miso,
    output wire nrf_ce,
    output wire nrf_csn,
    input  wire nrf_irq,
    
    output wire [3:0] leds
);

    wire w_spi_start, w_spi_busy;
    wire [7:0] w_spi_tx, w_spi_rx;
    wire [3:0] w_state_debug;

    // 1. SPI MASTER (Dùng l?i module ?ã có)
    spi_master #(.CLK_DIV(50)) spi_inst (
        .clk(clk), .reset(reset_btn),
        .start(w_spi_start), .data_tx(w_spi_tx), .data_rx(w_spi_rx), .busy(w_spi_busy),
        .sck(nrf_sck), .mosi(nrf_mosi), .miso(nrf_miso)
    );

    // 2. TX TEST CORE (Module m?i vi?t ? trên)
    nrf_tx_test_core tx_core (
        .clk(clk), .reset(reset_btn),
        .spi_start(w_spi_start), .spi_tx(w_spi_tx), .spi_rx(w_spi_rx), .spi_busy(w_spi_busy),
        .ce(nrf_ce), .csn(nrf_csn),
        .state_debug(w_state_debug)
    );

    // LED 0 nháy theo nh?p g?i d? li?u (tr?ng thái Pulse CE)
        assign leds[0] = nrf_ce; 
        // LED 1-3 hi?n th? tr?ng thái FSM ?? debug
        assign leds[3:1] = w_state_debug[2:0];

endmodule