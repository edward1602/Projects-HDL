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
    // Parameters matching Arduino logic
    parameter CENTER_X = 360;      // Approximate center for X axis 
    parameter CENTER_Y = 360;      // Approximate center for Y axis
    parameter FORWARD_MIN = 390;   // Y > 390 for forward
    parameter FORWARD_MAX = 420;   // Y >= 420 for max forward speed
    parameter BACKWARD_MIN = 310;  // X < 310 for backward  
    parameter BACKWARD_MAX = 335;  // X <= 335 for max backward speed
    parameter TURN_LEFT = 320;     // X < 320 for left turn
    parameter TURN_RIGHT = 400;    // X > 400 for right turn
    parameter MIN_SPEED = 100;     // Minimum motor speed
    parameter MAX_SPEED = 255;     // Maximum motor speed
    
    always @(posedge clk) begin
        if (reset) begin
            speed <= 0;
            direction <= 4'b0000;
        end else if (valid) begin
            // Forward motion: Y > 390
            if (accel_y > FORWARD_MIN) begin
                direction <= 4'b1010; // Forward direction
                if (accel_y >= FORWARD_MAX) begin
                    speed <= MAX_SPEED;
                end else begin
                    // Map Y from 390-420 to speed 100-255
                    speed <= MIN_SPEED + ((accel_y - FORWARD_MIN) * (MAX_SPEED - MIN_SPEED)) / (FORWARD_MAX - FORWARD_MIN);
                end
            end
            // Backward motion: X < 310  
            else if (accel_x < BACKWARD_MIN) begin
                direction <= 4'b0101; // Backward direction
                if (accel_x <= BACKWARD_MAX) begin
                    speed <= MAX_SPEED;
                end else begin
                    // Map X from 310-335 to speed 255-100 (reverse mapping)
                    speed <= MAX_SPEED - ((accel_x - BACKWARD_MAX) * (MAX_SPEED - MIN_SPEED)) / (BACKWARD_MIN - BACKWARD_MAX);
                end
            end
            // Left turn: X < 320
            else if (accel_x < TURN_LEFT) begin
                direction <= 4'b0110; // Left turn direction
                speed <= 150; // Fixed speed for turns
            end
            // Right turn: X > 400
            else if (accel_x > TURN_RIGHT) begin
                direction <= 4'b1001; // Right turn direction  
                speed <= 150; // Fixed speed for turns
            end
            // Stop condition
            else begin
                direction <= 4'b0000;
                speed <= 0;
            end
        end
    end
endmodule