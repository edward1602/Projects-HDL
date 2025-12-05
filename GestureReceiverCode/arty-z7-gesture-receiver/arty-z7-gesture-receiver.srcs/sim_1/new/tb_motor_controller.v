`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Testbench for Motor Controller Module
// Tests all movement directions based on gesture sensor data
//////////////////////////////////////////////////////////////////////////////////

module tb_motor_controller;

    // Parameters
    parameter CLK_PERIOD = 10;  // 10ns = 100MHz
    parameter CLK_FREQ = 100_000_000;
    
    // Testbench signals
    reg clk;
    reg rst_n;
    reg [15:0] x_axis;
    reg [15:0] y_axis;
    reg [15:0] z_axis;
    reg data_valid;
    
    wire motor_a1;
    wire motor_a2;
    wire motor_b1;
    wire motor_b2;
    wire pwm_ena;
    wire pwm_enb;
    
    // Instantiate the motor controller
    motor_controller #(
        .CLK_FREQ(CLK_FREQ),
        .PWM_FREQ(1000),
        .TIMEOUT_MS(100)  // Shorter timeout for simulation
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .x_axis(x_axis),
        .y_axis(y_axis),
        .z_axis(z_axis),
        .data_valid(data_valid),
        .motor_a1(motor_a1),
        .motor_a2(motor_a2),
        .motor_b1(motor_b1),
        .motor_b2(motor_b2),
        .pwm_ena(pwm_ena),
        .pwm_enb(pwm_enb)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Monitor motor states - wait 2 clocks for motor_controller pipeline
    reg [1:0] monitor_delay;
    always @(posedge clk) begin
        if (data_valid) begin
            monitor_delay <= 2;
        end else if (monitor_delay > 0) begin
            monitor_delay <= monitor_delay - 1;
            if (monitor_delay == 1) begin
                // Display after 2 clock cycles
                $display("\n=== Time: %0t ns ===", $time);
                $display("Input: X=%d, Y=%d, Z=%d", x_axis, y_axis, z_axis);
                $display("Motor A: A1=%b A2=%b PWM_ENA=%b", motor_a1, motor_a2, pwm_ena);
                $display("Motor B: B1=%b B2=%b PWM_ENB=%b", motor_b1, motor_b2, pwm_enb);
                
                // Decode direction
                if (motor_a1 == 0 && motor_a2 == 1 && motor_b1 == 1 && motor_b2 == 0)
                    $display("Direction: FORWARD");
                else if (motor_a1 == 1 && motor_a2 == 0 && motor_b1 == 0 && motor_b2 == 1)
                    $display("Direction: BACKWARD");
                else if (motor_a1 == 1 && motor_a2 == 0 && motor_b1 == 1 && motor_b2 == 0)
                    $display("Direction: LEFT");
                else if (motor_a1 == 0 && motor_a2 == 1 && motor_b1 == 0 && motor_b2 == 1)
                    $display("Direction: RIGHT");
                else if (motor_a1 == 0 && motor_a2 == 0 && motor_b1 == 0 && motor_b2 == 0)
                    $display("Direction: STOP");
                else
                    $display("Direction: UNKNOWN");
            end
        end
    end
    
    // Test stimulus
    initial begin
        $display("===========================================");
        $display("Motor Controller Testbench Started");
        $display("===========================================");
        
        // Initialize signals
        rst_n = 0;
        x_axis = 16'd350;   // Neutral
        y_axis = 16'd350;   // Neutral
        z_axis = 16'd350;
        data_valid = 0;
        
        // Reset
        #(CLK_PERIOD * 10);
        rst_n = 1;
        #(CLK_PERIOD * 10);
        
        //=================================================
        // TEST 1: FORWARD - Minimum speed (Y = 391)
        //=================================================
        $display("\n### TEST 1: FORWARD - Min Speed ###");
        x_axis = 16'd350;
        y_axis = 16'd391;
        z_axis = 16'd350;
        data_valid = 1;
        #CLK_PERIOD;
        data_valid = 0;
        #(CLK_PERIOD * 1000);  // Wait to observe PWM
        
        //=================================================
        // TEST 2: FORWARD - Max speed (Y = 420)
        //=================================================
        $display("\n### TEST 2: FORWARD - Max Speed ###");
        x_axis = 16'd350;
        y_axis = 16'd420;
        z_axis = 16'd350;
        data_valid = 1;
        #CLK_PERIOD;
        data_valid = 0;
        #(CLK_PERIOD * 1000);
        
        //=================================================
        // TEST 3: BACKWARD - Min speed (X = 309)
        //=================================================
        $display("\n### TEST 3: BACKWARD - Min Speed ###");
        x_axis = 16'd309;
        y_axis = 16'd350;
        z_axis = 16'd350;
        data_valid = 1;
        #CLK_PERIOD;
        data_valid = 0;
        #(CLK_PERIOD * 1000);
        
        //=================================================
        // TEST 4: BACKWARD - Max speed (X = 335)
        //=================================================
        $display("\n### TEST 4: BACKWARD - Max Speed ###");
        x_axis = 16'd335;
        y_axis = 16'd350;
        z_axis = 16'd350;
        data_valid = 1;
        #CLK_PERIOD;
        data_valid = 0;
        #(CLK_PERIOD * 1000);
        
        //=================================================
        // TEST 5: LEFT (X = 315)
        //=================================================
        $display("\n### TEST 5: LEFT ###");
        x_axis = 16'd315;
        y_axis = 16'd350;
        z_axis = 16'd350;
        data_valid = 1;
        #CLK_PERIOD;
        data_valid = 0;
        #(CLK_PERIOD * 1000);
        
        //=================================================
        // TEST 6: RIGHT (X = 405)
        //=================================================
        $display("\n### TEST 6: RIGHT ###");
        x_axis = 16'd405;
        y_axis = 16'd350;
        z_axis = 16'd350;
        data_valid = 1;
        #CLK_PERIOD;
        data_valid = 0;
        #(CLK_PERIOD * 1000);
        
        //=================================================
        // TEST 7: STOP - Neutral position
        //=================================================
        $display("\n### TEST 7: STOP - Neutral ###");
        x_axis = 16'd350;
        y_axis = 16'd350;
        z_axis = 16'd350;
        data_valid = 1;
        #CLK_PERIOD;
        data_valid = 0;
        #(CLK_PERIOD * 1000);
        
        //=================================================
        // TEST 8: Connection timeout
        //=================================================
        $display("\n### TEST 8: Connection Timeout ###");
        $display("Waiting for timeout (no new data)...");
        x_axis = 16'd405;  // Right command
        y_axis = 16'd350;
        z_axis = 16'd350;
        data_valid = 1;
        #CLK_PERIOD;
        data_valid = 0;
        
        // Wait for timeout (100ms in simulation)
        #(CLK_PERIOD * 100_000 * 100);  // 100ms * 100MHz
        
        $display("After timeout - motors should STOP");
        #(CLK_PERIOD * 100);
        
        //=================================================
        // TEST 9: Fixed data test (matching transmitter)
        //=================================================
        $display("\n### TEST 9: Fixed Data from Transmitter ###");
        x_axis = 16'd100;
        y_axis = 16'd120;
        z_axis = 16'd140;
        data_valid = 1;
        #CLK_PERIOD;
        data_valid = 0;
        #(CLK_PERIOD * 1000);
        
        //=================================================
        // End of test
        //=================================================
        #(CLK_PERIOD * 1000);
        $display("\n===========================================");
        $display("Motor Controller Testbench Completed");
        $display("===========================================");
        $finish;
    end
    
    // Watchdog timer
    initial begin
        #(CLK_PERIOD * 20_000_000);  // Max simulation time
        $display("\nERROR: Simulation timeout!");
        $finish;
    end

endmodule
