`timescale 1ns/1ps

module tb_top;

    // Clock generation (125 MHz -> 8 ns period)
    reg clk = 1'b0;
    always #4 clk = ~clk;

    // Reset logic (active-high button)
    reg reset_btn = 1'b1;

    // Wires to observe
    wire        nrf_ce;
    wire        nrf_csn;
    wire        nrf_sck;
    wire        nrf_mosi;
    reg         nrf_miso_reg = 1'b1;
    wire        nrf_miso    = nrf_miso_reg;
    reg         nrf_irq     = 1'b1;   // unused when USE_IRQ=0
    wire [3:0]  leds;

    // Device Under Test
    top dut (
        .clk       (clk),
        .reset_btn (reset_btn),
        .nrf_ce    (nrf_ce),
        .nrf_csn   (nrf_csn),
        .nrf_irq   (nrf_irq),
        .nrf_sck   (nrf_sck),
        .nrf_mosi  (nrf_mosi),
        .nrf_miso  (nrf_miso),
        .leds      (leds)
    );

    

endmodule