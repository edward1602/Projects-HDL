`timescale 1ns / 1ps

module robot_receiver_top (
    input wire clk,
    input wire reset_btn,
    output wire nrf_ce,
    output wire nrf_csn,
    output wire nrf_sck,
    output wire nrf_mosi,
    input wire nrf_miso,
    output wire pwm_motor_a,
    output wire pwm_motor_b,
    output wire [3:0] motor_dir,
    output wire [3:0] led
);
    wire reset;
    wire [7:0] payload_0, payload_1, payload_2, payload_3, payload_4, payload_5;
    wire nrf_data_ready;
    wire signed [15:0] accel_x, accel_y, accel_z;
    wire accel_valid;
    wire [7:0] motor_speed;
    wire [3:0] motor_direction;
    
    wire spi_start;
    wire [7:0] spi_tx, spi_rx;
    wire spi_busy;
    
    reg [1:0] reset_sync;
    always @(posedge clk) begin
        reset_sync <= {reset_sync[0], ~reset_btn};
    end
    assign reset = reset_sync[1];
    
    spi_master spi (
        .clk(clk),
        .reset(reset),
        .start(spi_start),
        .data_tx(spi_tx),
        .data_rx(spi_rx),
        .busy(spi_busy),
        .sck(nrf_sck),
        .mosi(nrf_mosi),
        .miso(nrf_miso)
    );
    
    nrf24l01_controller nrf (
        .clk(clk),
        .reset(reset),
        .payload_0(payload_0),
        .payload_1(payload_1),
        .payload_2(payload_2),
        .payload_3(payload_3),
        .payload_4(payload_4),
        .payload_5(payload_5),
        .data_ready(nrf_data_ready),
        .spi_start(spi_start),
        .spi_tx(spi_tx),
        .spi_rx(spi_rx),
        .spi_busy(spi_busy),
        .ce(nrf_ce),
        .csn(nrf_csn)
    );
    
    data_parser parser (
        .clk(clk),
        .reset(reset),
        .payload_0(payload_0),
        .payload_1(payload_1),
        .payload_2(payload_2),
        .payload_3(payload_3),
        .payload_4(payload_4),
        .payload_5(payload_5),
        .data_ready(nrf_data_ready),
        .accel_x(accel_x),
        .accel_y(accel_y),
        .accel_z(accel_z),
        .valid(accel_valid)
    );
    
    motion_controller controller (
        .clk(clk),
        .reset(reset),
        .accel_x(accel_x),
        .accel_y(accel_y),
        .accel_z(accel_z),
        .valid(accel_valid),
        .speed(motor_speed),
        .direction(motor_direction)
    );
    
    pwm_generator pwm_a (
        .clk(clk),
        .reset(reset),
        .duty_cycle(motor_speed),
        .pwm_out(pwm_motor_a)
    );
    
    pwm_generator pwm_b (
        .clk(clk),
        .reset(reset),
        .duty_cycle(motor_speed),
        .pwm_out(pwm_motor_b)
    );
    
    assign motor_dir = motor_direction;
    
    assign led[0] = nrf_data_ready;
    assign led[1] = accel_valid;
    assign led[2] = |motor_speed;
    assign led[3] = reset;
    
endmodule
