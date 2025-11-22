`timescale 1ns / 1ps

module motion_controller (
    input wire clk,
    input wire reset,
    input wire signed [15:0] accel_x,
    input wire signed [15:0] accel_y,
    input wire signed [15:0] accel_z,
    input wire valid,
    output reg [7:0] speed,
    output reg [3:0] direction
);
    parameter CENTER = 512;
    parameter THRESHOLD = 100;
    parameter MAX_SPEED = 255;
    
    reg signed [15:0] x_offset, y_offset;
    
    always @(posedge clk) begin
        if (reset) begin
            speed <= 0;
            direction <= 4'b0000;
            x_offset <= 0;
            y_offset <= 0;
        end else if (valid) begin
            x_offset = accel_x - CENTER;
            y_offset = accel_y - CENTER;
            
            if (x_offset > -THRESHOLD && x_offset < THRESHOLD &&
                y_offset > -THRESHOLD && y_offset < THRESHOLD) begin
                speed <= 0;
                direction <= 4'b0000;
            end
            else if (y_offset > THRESHOLD) begin
                direction <= 4'b1010;
                speed <= (y_offset > 300) ? MAX_SPEED : ((y_offset - THRESHOLD) * 255 / 300);
            end
            else if (y_offset < -THRESHOLD) begin
                direction <= 4'b0101;
                speed <= (y_offset < -300) ? MAX_SPEED : (((-y_offset) - THRESHOLD) * 255 / 300);
            end
            else if (x_offset > THRESHOLD) begin
                direction <= 4'b1001;
                speed <= (x_offset > 300) ? MAX_SPEED : ((x_offset - THRESHOLD) * 255 / 300);
            end
            else if (x_offset < -THRESHOLD) begin
                direction <= 4'b0110;
                speed <= (x_offset < -300) ? MAX_SPEED : (((-x_offset) - THRESHOLD) * 255 / 300);
            end
        end
    end
endmodule