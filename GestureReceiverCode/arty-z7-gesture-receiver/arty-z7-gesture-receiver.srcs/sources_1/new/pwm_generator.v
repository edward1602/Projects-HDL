`timescale 1ns / 1ps

module pwm_generator (
    input wire clk,
    input wire reset,
    input wire [7:0] duty_cycle,
    output reg pwm_out
);
    reg [9:0] clk_divider;
    reg [7:0] pwm_counter;
    
    always @(posedge clk) begin
        if (reset) begin
            clk_divider <= 0;
            pwm_counter <= 0;
            pwm_out <= 0;
        end else begin
            if (clk_divider == 1023) begin
                clk_divider <= 0;
                pwm_counter <= pwm_counter + 1;
            end else begin
                clk_divider <= clk_divider + 1;
            end
            
            pwm_out <= (pwm_counter < duty_cycle) ? 1'b1 : 1'b0;
        end
    end
endmodule