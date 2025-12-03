module top (
    input clk,
    input reset_btn,
    output nrf_ce,
    output nrf_csn,
    input nrf_irq,
    output nrf_sck,
    output nrf_mosi,
    input nrf_miso,
    output payload_ready,
    output [3:0] leds
);

    localparam integer RESET_FILTER_MAX = 20'hFFFFF;
    localparam integer STARTUP_DELAY_CYCLES = 9'd255;
    localparam [26:0] LED0_HOLD_TICKS = 27'd25_000_000;

    wire rst_n;
    wire rx_ready;
    wire [47:0] rx_payload;
    wire payload_ready_pulse;

    reg [19:0] reset_counter;
    reg reset_sync;

    always @(posedge clk) begin
        if (reset_btn) begin
            reset_counter <= 20'h00000;
            reset_sync <= 1'b0;
        end else if (reset_counter < RESET_FILTER_MAX) begin
            reset_counter <= reset_counter + 1'b1;
        end else begin
            reset_sync <= 1'b1;
        end
    end

    assign rst_n = reset_sync;

    reg start_rx_reg;
    reg [8:0] startup_counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_rx_reg <= 1'b0;
            startup_counter <= 9'd0;
        end else if (startup_counter < STARTUP_DELAY_CYCLES) begin
            startup_counter <= startup_counter + 1'b1;
            start_rx_reg <= 1'b0;
        end else if (startup_counter == STARTUP_DELAY_CYCLES) begin
            start_rx_reg <= 1'b1;
            startup_counter <= startup_counter + 1'b1;
        end else begin
            start_rx_reg <= 1'b0;
        end
    end

    nrf24l01_simple_rx_controller #(
        .USE_IRQ(0)
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

    reg [3:0] led_state;
    reg [26:0] led0_counter;
    reg led0_latched;
    reg [47:0] last_payload;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            led0_counter <= 27'd0;
            led0_latched <= 1'b0;
            last_payload <= 48'h0;
        end else begin
            if (led0_counter != 0) begin
                led0_counter <= led0_counter - 1'b1;
                if (led0_counter == 1)
                    led0_latched <= 1'b0;
            end

            if (payload_ready_pulse) begin
                if (rx_payload != last_payload) begin
                    led0_latched <= 1'b1;
                    led0_counter <= LED0_HOLD_TICKS;
                end
                last_payload <= rx_payload;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            led_state <= 4'b0000;
        end else begin
            led_state[0] <= led0_latched;
            led_state[1] <= nrf_sck;
            led_state[2] <= rx_ready;
            led_state[3] <= nrf_csn;
        end
    end

    assign leds = led_state;
    assign payload_ready = payload_ready_pulse;

endmodule