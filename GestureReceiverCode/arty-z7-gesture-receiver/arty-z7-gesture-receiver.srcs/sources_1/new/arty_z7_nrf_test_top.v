module arty_z7_nrf_test_top (
    // System clock and reset
    input clk,           // 125MHz system clock
    input reset_btn,     // Reset button (active high)
    
    // NRF24L01 interface
    output nrf_ce,       // Chip Enable
    output nrf_csn,      // SPI Chip Select (active low)
    input nrf_irq,       // Interrupt (active low)
    output nrf_sck,      // SPI Clock
    output nrf_mosi,     // SPI Master Out Slave In
    input nrf_miso,      // SPI Master In Slave Out
    
    // Debug LEDs (4 LEDs available)
    output [3:0] leds
);

    // Internal signals
    wire rst_n;
    wire rx_ready;
    wire [47:0] rx_payload;
    wire payload_ready;
    
    // Button debouncing and reset logic
    reg [19:0] reset_counter;
    reg reset_sync;
    
    always @(posedge clk) begin
        if (reset_btn) begin
            reset_counter <= 20'h0;
            reset_sync <= 1'b0;
        end else if (reset_counter < 20'hFFFFF) begin
            reset_counter <= reset_counter + 1;
        end else begin
            reset_sync <= 1'b1;
        end
    end
    
    assign rst_n = reset_sync;
    
    // Auto-start RX after reset
    reg start_rx_reg;
    reg [7:0] startup_counter;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_rx_reg <= 1'b0;
            startup_counter <= 8'h0;
        end else begin
            if (startup_counter < 8'hFF) begin
                startup_counter <= startup_counter + 1;
                start_rx_reg <= 1'b0;
            end else if (startup_counter == 8'hFF) begin
                start_rx_reg <= 1'b1;  // Start RX after delay
                startup_counter <= startup_counter + 1;
            end else begin
                start_rx_reg <= 1'b0;
            end
        end
    end
    
    // NRF24L01 Controller instantiation
    nrf24l01_simple_rx_controller nrf_controller (
        .clk(clk),
        .rst_n(rst_n),
        .start_rx(start_rx_reg),
        .rx_ready(rx_ready),
        .nrf_ce(nrf_ce),
        .nrf_csn(nrf_csn),
        .nrf_irq(nrf_irq),
        .spi_sck(nrf_sck),
        .spi_mosi(nrf_mosi),
        .spi_miso(nrf_miso),
        .rx_payload(rx_payload),
        .payload_ready(payload_ready)
    );
    
    // LED Debug Logic
    reg [3:0] led_state;
    reg [25:0] blink_counter;  // For blinking LEDs
    reg payload_received_flag;
    reg [15:0] payload_count;   // Count received payloads
    
    // Payload counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            payload_count <= 16'h0;
            payload_received_flag <= 1'b0;
        end else begin
            if (payload_ready) begin
                payload_count <= payload_count + 1;
                payload_received_flag <= 1'b1;
            end else if (blink_counter == 26'h3FFFFFF) begin // Reset flag after ~0.5s
                payload_received_flag <= 1'b0;
            end
        end
    end
    
    // Blink counter (for timing)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            blink_counter <= 26'h0;
        end else begin
            blink_counter <= blink_counter + 1;
        end
    end
    
    // LED State Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            led_state <= 4'b0000;
        end else begin
            // LED[0] - Power/Reset indicator (always ON when system ready)
            led_state[0] <= rst_n;
            
            // LED[1] - RX Ready (ON when NRF is ready to receive)
            led_state[1] <= rx_ready;
            
            // LED[2] - Payload received indicator (blinks when data received)
            if (payload_received_flag) begin
                led_state[2] <= blink_counter[22]; // Fast blink (~12Hz)
            end else begin
                led_state[2] <= 1'b0;
            end
            
            // LED[3] - SPI Activity / IRQ Status debug
            // Show SPI activity or IRQ status to debug communication
            if (payload_count > 0) begin
                // If we have received payloads, show count
                case (payload_count[1:0])
                    2'b00: led_state[3] <= 1'b0;
                    2'b01: led_state[3] <= blink_counter[24];       // Slow blink
                    2'b10: led_state[3] <= blink_counter[23];       // Medium blink  
                    2'b11: led_state[3] <= blink_counter[22];       // Fast blink
                endcase
            end else begin
                // No payloads yet - show IRQ status for debug
                led_state[3] <= ~nrf_irq;  // ON when IRQ is asserted (active low)
            end
        end
    end
    
    assign leds = led_state;

endmodule