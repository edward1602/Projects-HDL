module arty_z7_gesture_receiver (
    // Arty Z7 clock input (100 MHz)
    input CLK100MHZ,
    
    // Arty Z7 reset button (active low)
    input ck_rst,
    
    // Arty Z7 LEDs for status indication
    output [3:0] led,
    
    // NRF24L01 connections
    output nrf_ce,
    output nrf_csn, 
    output nrf_sck,
    output nrf_mosi,
    input nrf_miso,
    input nrf_irq,
    
    // Optional: GPIO outputs for gesture data (for external processing)
    output [15:0] gpio_x_axis,
    output [15:0] gpio_y_axis, 
    output [15:0] gpio_z_axis,
    output gpio_data_valid
);

    // Internal signals
    wire clk = CLK100MHZ;
    wire rst_n = ck_rst; // Arty Z7 reset button
    
    // Gesture receiver signals
    wire rx_ready;
    wire [47:0] rx_payload;
    wire payload_ready;
    
    // Extracted gesture data (Little-Endian format)
    wire [15:0] x_axis = {rx_payload[15:8], rx_payload[7:0]};   // Bytes 1,0
    wire [15:0] y_axis = {rx_payload[31:24], rx_payload[23:16]}; // Bytes 3,2  
    wire [15:0] z_axis = {rx_payload[47:40], rx_payload[39:32]}; // Bytes 5,4
    
    // LED status indicators
    assign led[0] = rx_ready;      // LED 0: RX ready status
    assign led[1] = payload_ready; // LED 1: New data received
    assign led[2] = nrf_irq;       // LED 2: IRQ status (active low)
    assign led[3] = |{x_axis[15:12], y_axis[15:12], z_axis[15:12]}; // LED 3: Data activity
    
    // GPIO outputs for external use
    assign gpio_x_axis = x_axis;
    assign gpio_y_axis = y_axis;
    assign gpio_z_axis = z_axis;
    assign gpio_data_valid = payload_ready;
    
    // Simple NRF24L01 RX Controller
    nrf24l01_simple_rx_controller nrf_rx (
        .clk(clk),
        .rst_n(rst_n),
        
        // Simple interface
        .start_rx(1'b1), // Always start RX after reset
        .rx_ready(rx_ready),
        
        // NRF24L01 hardware pins
        .nrf_ce(nrf_ce),
        .nrf_csn(nrf_csn),
        .nrf_irq(nrf_irq),
        
        // SPI interface
        .spi_sck(nrf_sck),
        .spi_mosi(nrf_mosi),
        .spi_miso(nrf_miso),
        
        // Received data
        .rx_payload(rx_payload),
        .payload_ready(payload_ready)
    );
    
    // Optional: Debug/monitoring logic
    // You can add ILA (Integrated Logic Analyzer) here for debugging
    
endmodule