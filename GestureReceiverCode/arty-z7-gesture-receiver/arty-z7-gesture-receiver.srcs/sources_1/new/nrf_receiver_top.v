`timescale 1ns / 1ps

// Top-level module, connects all components:
// 1. spi_master
// 2. nrf24l01_controller
// 3. data_parser
module nrf_receiver_top(
    input wire clk,
    input wire reset,
    
    // Physical pins connected to the NRF24L01 module
    output wire spi_sck,
    output wire spi_mosi, 
    input wire spi_miso, 
    output wire nrf_ce, 
    output wire nrf_csn,
    
    // Decoded data outputs (for user logic)
    output wire [15:0] x_axis_raw,
    output wire [15:0] y_axis_raw,
    output wire [15:0] z_axis_raw,
    output wire new_data_valid
);

    // ====================================================================
    // Internal Signals (Module Interconnection)
    // ====================================================================
    
    // Signals between NRF Controller and SPI Master
    wire spi_start_pulse;
    wire [7:0] spi_tx_data;
    wire spi_busy_flag;
    wire [7:0] spi_rx_data; 

    // Payload Signals (Controller output, Parser input)
    wire [7:0] p0, p1, p2, p3, p4, p5;
    wire data_ready_flag;

    // ====================================================================
    // 1. SPI Master Instantiation
    // ====================================================================
    // Assumes system CLK is 100MHz. CLK_DIV=50 results in a 2MHz SPI frequency.
    spi_master #(.CLK_DIV(50)) spi_inst (
        .clk(clk),
        .reset(reset),
        .start(spi_start_pulse), 
        .data_tx(spi_tx_data),   
        .data_rx(spi_rx_data),   
        .busy(spi_busy_flag),    
        .sck(spi_sck),           
        .mosi(spi_mosi),         
        .miso(spi_miso)          
    );

    // ====================================================================
    // 2. NRF24L01 Controller Instantiation
    // ====================================================================
    nrf24l01_controller nrf_ctrl_inst (
        .clk(clk),
        .reset(reset),
        
        // Output Payload (Connected to data_parser)
        .payload_0(p0), 
        .payload_1(p1), 
        .payload_2(p2), 
        .payload_3(p3), 
        .payload_4(p4), 
        .payload_5(p5), 
        .data_ready(data_ready_flag), 
        
        // SPI Master Interface
        .spi_start(spi_start_pulse), 
        .spi_tx(spi_tx_data),       
        .spi_rx(spi_rx_data),       
        .spi_busy(spi_busy_flag),   
        
        // NRF Control Pins
        .ce(nrf_ce),
        .csn(nrf_csn)
    );

    // ====================================================================
    // 3. Data Parser Instantiation (Handles byte concatenation)
    // ====================================================================
    data_parser data_parser_inst (
        .clk(clk),
        .reset(reset),
        .payload_0(p0), 
        .payload_1(p1), 
        .payload_2(p2), 
        .payload_3(p3), 
        .payload_4(p4), 
        .payload_5(p5), 
        .data_ready(data_ready_flag),
        
        .accel_x(x_axis_raw),      
        .accel_y(y_axis_raw),      
        .accel_z(z_axis_raw),      
        .valid(new_data_valid)     
    );

endmodule