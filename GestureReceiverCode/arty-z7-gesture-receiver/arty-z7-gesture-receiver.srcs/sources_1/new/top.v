module top (
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
    
    // Debug signal
    output payload_ready,
    
    // Debug LEDs (4 LEDs available)
    output [3:0] leds
);

    // Internal signals
    wire rst_n;
    wire rx_ready;
    wire [47:0] rx_payload;
    wire payload_ready_pulse; // Raw 1-cycle pulse from controller
    
    
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
    reg [8:0] startup_counter; // Extend to 9 bits to prevent overflow
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_rx_reg <= 1'b0;
            startup_counter <= 9'h0;
        end else begin
            if (startup_counter < 9'd255) begin
                startup_counter <= startup_counter + 1;
                start_rx_reg <= 1'b0;
            end else if (startup_counter == 9'd255) begin
                start_rx_reg <= 1'b1;  // Pulse start_rx signal for one cycle
                startup_counter <= startup_counter + 1; // Move to 256
            end else begin
                start_rx_reg <= 1'b0;  // Keep start_rx low, counter stays > 255
            end
        end
    end
    
    // NRF24L01 Controller instantiation
    nrf24l01_simple_rx_controller #(
        .USE_IRQ(1)
    ) nrf_controller (
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
        .payload_ready(payload_ready_pulse)
    );
    
    // State value aliases for LED debug
    localparam [4:0] STATE_RX_READ_PAYLOAD_CMD  = 5'd13;
    localparam [4:0] STATE_RX_READ_PAYLOAD_BYTE = 5'd14;
    localparam [4:0] STATE_RX_CLEAR_IRQ         = 5'd15;
    localparam [26:0] LED0_HOLD_TICKS = 27'd62_500_000; // ~500ms at 125MHz

    // LED Debug Logic
    reg [3:0] led_state;
    reg [26:0] led0_counter;
    reg        led0_latched;
    
    // Blink counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            led0_counter <= 27'd0;
            led0_latched <= 1'b0;
        end else begin
            if (payload_ready_pulse) begin
                led0_latched <= 1'b1;
                led0_counter <= LED0_HOLD_TICKS;
            end else if (led0_counter != 0) begin
                led0_counter <= led0_counter - 1'b1;
                if (led0_counter == 1)
                    led0_latched <= 1'b0;
            end else begin
                led0_latched <= 1'b0;
            end
        end
    end
    
    // LED State Logic - Debug Version
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            led_state <= 4'b0000;
        end else begin
            led_state[0] <= led0_latched;
            
            led_state[1] <= nrf_sck;
            
            // LED[2] - On while controller reads payload or clears IRQ
            if (nrf_controller.current_state == STATE_RX_READ_PAYLOAD_CMD ||
                nrf_controller.current_state == STATE_RX_READ_PAYLOAD_BYTE ||
                nrf_controller.current_state == STATE_RX_CLEAR_IRQ)
                led_state[2] <= 1'b1;
            else
                led_state[2] <= 1'b0;
            
            led_state[3] <= nrf_csn;
        end
    end

    assign leds = led_state;
    assign payload_ready = payload_ready_pulse; // Expose raw 1-cycle pulse for external measurement
    
endmodule