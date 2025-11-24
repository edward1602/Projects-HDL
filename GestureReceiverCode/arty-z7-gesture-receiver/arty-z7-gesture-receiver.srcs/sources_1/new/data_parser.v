`timescale 1ns / 1ps

module data_parser (
    input wire clk,
    input wire reset,
    input wire [7:0] payload_0,
    input wire [7:0] payload_1,
    input wire [7:0] payload_2,
    input wire [7:0] payload_3,
    input wire [7:0] payload_4,
    input wire [7:0] payload_5,
    input wire data_ready,
    output reg [15:0] accel_x,
    output reg [15:0] accel_y,
    output reg [15:0] accel_z,
    output reg valid
);
    always @(posedge clk) begin
        if (reset) begin
            accel_x <= 0;
            accel_y <= 0;
            accel_z <= 0;
            valid <= 0;
        end else if (data_ready) begin
            accel_x <= {payload_1, payload_0};
            accel_y <= {payload_3, payload_2};
            accel_z <= {payload_5, payload_4};
            valid <= 1;
        end else begin
            valid <= 0;
        end
    end
endmodule