`timescale 1ns / 1ps

module tb_data_parser;

    // DUT inputs
    reg clk;
    reg reset;
    reg [7:0] payload_0;
    reg [7:0] payload_1;
    reg [7:0] payload_2;
    reg [7:0] payload_3;
    reg [7:0] payload_4;
    reg [7:0] payload_5;
    reg data_ready;

    // DUT outputs
    wire [15:0] accel_x;
    wire [15:0] accel_y;
    wire [15:0] accel_z;
    wire valid;

    // Instantiate DUT
    data_parser uut (
        .clk(clk),
        .reset(reset),
        .payload_0(payload_0),
        .payload_1(payload_1),
        .payload_2(payload_2),
        .payload_3(payload_3),
        .payload_4(payload_4),
        .payload_5(payload_5),
        .data_ready(data_ready),
        .accel_x(accel_x),
        .accel_y(accel_y),
        .accel_z(accel_z),
        .valid(valid)
    );

    // Clock generation: 100 MHz
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Stimulus
    initial begin
        // Initialize
        reset = 1;
        data_ready = 0;
        payload_0 = 0;
        payload_1 = 0;
        payload_2 = 0;
        payload_3 = 0;
        payload_4 = 0;
        payload_5 = 0;

        #20;
        reset = 0;

        // Test case 1: g?i d? li?u gi? l?p
        @(posedge clk);
        payload_0 = 8'h11;
        payload_1 = 8'h22;
        payload_2 = 8'h33;
        payload_3 = 8'h44;
        payload_4 = 8'h55;
        payload_5 = 8'h66;
        data_ready = 1;

        @(posedge clk);
        data_ready = 0; // h? xu?ng

        // Ch? m?t chút
        #20;
        $display("Accel X = %h, Accel Y = %h, Accel Z = %h, Valid = %b",
                  accel_x, accel_y, accel_z, valid);

        // Test case 2: d? li?u khác
        @(posedge clk);
        payload_0 = 8'hAA;
        payload_1 = 8'hBB;
        payload_2 = 8'hCC;
        payload_3 = 8'hDD;
        payload_4 = 8'hEE;
        payload_5 = 8'hFF;
        data_ready = 1;

        @(posedge clk);
        data_ready = 0;

        #20;
        $display("Accel X = %h, Accel Y = %h, Accel Z = %h, Valid = %b",
                  accel_x, accel_y, accel_z, valid);

        #50;
        $finish;
    end

    // Monitor ?? quan sát liên t?c
    initial begin
        $monitor("t=%0t ns : data_ready=%b valid=%b accel_x=%h accel_y=%h accel_z=%h",
                 $time, data_ready, valid, accel_x, accel_y, accel_z);
    end

endmodule
