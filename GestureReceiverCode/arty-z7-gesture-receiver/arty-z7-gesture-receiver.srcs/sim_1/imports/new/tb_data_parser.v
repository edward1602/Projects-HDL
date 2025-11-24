`timescale 1ns / 1ps

module tb_data_parser;

    // ====================================================================
    // 1. MODULE INTERFACE SIGNALS
    // ====================================================================
    reg clk;
    reg reset;
    reg data_ready;
    
    // Simulate Payload inputs (Little Endian: LSB, MSB)
    reg [7:0] payload_0, payload_1; 
    reg [7:0] payload_2, payload_3; 
    reg [7:0] payload_4, payload_5; 

    // Outputs from Data Parser
    wire [15:0] accel_x;
    wire [15:0] accel_y;
    wire [15:0] accel_z;
    wire valid;

    // ====================================================================
    // 2. UUT INSTANTIATION
    // ====================================================================
    data_parser uut (
        .clk(clk),
        .reset(reset),
        .payload_0(payload_0), .payload_1(payload_1),
        .payload_2(payload_2), .payload_3(payload_3),
        .payload_4(payload_4), .payload_5(payload_5),
        .data_ready(data_ready),
        .accel_x(accel_x), .accel_y(accel_y), .accel_z(accel_z),
        .valid(valid)
    );

    // ====================================================================
    // 3. Clock Generation & Constants
    // ====================================================================
    always #5 clk = ~clk; // 100MHz Clock

    // Constants for robust comparison
    localparam X_CASE1 = 16'h0200; 
    localparam Y_CASE1 = 16'h0270;
    localparam Z_CASE1 = 16'h01E0;
    
    localparam X_CASE2 = 16'h7FFF;
    localparam Y_CASE2 = 16'h7FFF;
    localparam Z_CASE2 = 16'h7FFF;

    localparam X_CASE3 = 16'h0000; 

    // ====================================================================
    // 4. Test Task Definition (FIXED SYNTAX)
    // ====================================================================
    task run_test_case;
        input integer case_num;
        input [7:0] p0, p1, p2, p3, p4, p5;      
        input [15:0] expected_x, expected_y, expected_z; 
        input [8*40-1:0] case_description; // Fixed: using register width instead of 'string'
        
        begin
            $display("\n[%0t] Running CASE %0d: %s", $time, case_num, case_description);
            
            // 1. Load Data
            payload_0 = p0; payload_1 = p1;
            payload_2 = p2; payload_3 = p3;
            payload_4 = p4; payload_5 = p5;
            
            // 2. Pulse Data Ready (Synchronous Latching)
            @(posedge clk) data_ready = 1;
            #10 data_ready = 0; // Data Ready is 1 for 1 cycle
            
            // 3. Verification (Wait 1 more cycle for valid flag to be set)
            @(posedge clk);
            
            // Check results
            if (valid == 1 && accel_x == expected_x && accel_y == expected_y && accel_z == expected_z) begin
                $display(">> [PASS] Case %0d: Data matched and Valid flag set.", case_num);
            end else begin
                $display(">> [FAIL] Case %0d: Data mismatch or Valid flag failed.", case_num);
                $display("   Expected X: 0x%h, Got X: 0x%h. Valid: %b", expected_x, accel_x, valid);
            end
        end
    endtask

    // ====================================================================
    // 5. Main Test Flow
    // ====================================================================
    reg [8*40-1:0] desc; // Variable to hold the description string
    initial begin
        // Initial 
        
        clk = 0; reset = 1; data_ready = 0;
        payload_0 = 8'h00; payload_1 = 8'h00; 
        payload_2 = 8'h00; payload_3 = 8'h00;
        payload_4 = 8'h00; payload_5 = 8'h00;

        $display("====================================================");
        $display("TEST START: data_parser functional verification");
        $display("====================================================");
        
        // 1. Release Reset
        #20 reset = 0; 
        
        // 2. Run Test Cases
        
        desc = "Standard Positive Data (512, 624, 480)";
        run_test_case(1, 8'h00, 8'h02, 8'h70, 8'h02, 8'hE0, 8'h01, X_CASE1, Y_CASE1, Z_CASE1, desc);

        desc = "Max Positive Data (0x7FFF)";
        run_test_case(2, 8'hFF, 8'h7F, 8'hFF, 8'h7F, 8'hFF, 8'h7F, X_CASE2, Y_CASE2, Z_CASE2, desc);

        desc = "Zero Data (0x0000)";
        run_test_case(3, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, X_CASE3, X_CASE3, X_CASE3, desc);

        #100;
        $stop;
    end
endmodule