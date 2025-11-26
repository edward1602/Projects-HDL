`timescale 1ns / 1ps

// Simple syntax check testbench
module tb_syntax_check;
    reg clk, rst_n, start_rx, nrf_irq, spi_miso;
    wire rx_ready, nrf_ce, nrf_csn, spi_sck, spi_mosi, payload_ready;
    wire [47:0] rx_payload;
    
    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk; // 100MHz
    
    // DUT instantiation
    nrf24l01_simple_rx_controller dut (
        .clk(clk),
        .rst_n(rst_n),
        .start_rx(start_rx),
        .rx_ready(rx_ready),
        .nrf_ce(nrf_ce),
        .nrf_csn(nrf_csn),
        .nrf_irq(nrf_irq),
        .spi_sck(spi_sck),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .rx_payload(rx_payload),
        .payload_ready(payload_ready)
    );
    
    initial begin
        $display("Syntax check started");
        rst_n = 0;
        start_rx = 0;
        nrf_irq = 1;
        spi_miso = 0;
        
        #100;
        rst_n = 1;
        #100;
        start_rx = 1;
        #10;
        start_rx = 0;
        
        #1000;
        $display("Syntax check completed successfully");
        $finish;
    end
    
endmodule