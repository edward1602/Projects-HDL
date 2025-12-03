`timescale 1ns / 1ps

module tb_payload_assembler;

    // --- 1. DUT Interface Signals ---
    reg clk;
    reg rst_n;
    reg [47:0] rx_payload_in;  // 48-bit payload (6 bytes)
    reg rx_data_valid_in;
    
    wire [15:0] x_axis_out;
    wire [15:0] y_axis_out;
    wire [15:0] z_axis_out;
    wire packet_ready;

    // --- 2. Internal variables ---
    reg [47:0] test_payload;  // 48-bit test payload
    
    // --- 3. Instantiate the Device Under Test (DUT) ---
    payload_assembler DUT (
        .clk(clk),
        .rst_n(rst_n),
        .rx_payload_in(rx_payload_in),
        .rx_data_valid_in(rx_data_valid_in),
        .x_axis_out(x_axis_out),
        .y_axis_out(y_axis_out),
        .z_axis_out(z_axis_out),
        .packet_ready(packet_ready)
    );

    // --- 4. Clock Generation ---
    parameter CLK_PERIOD = 10; 
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // --- 5. Test Stimulus ---
    initial begin
        // Test payload: X=0xABCD, Y=0xEF12, Z=0x3456 (Little-Endian)
        // Bit mapping: [47:40][39:32][31:24][23:16][15:8][7:0]
        //              Z_MSB   Z_LSB   Y_MSB   Y_LSB  X_MSB X_LSB
        //              0x34    0x56    0x12    0xEF   0xAB  0xCD
        test_payload = 48'h345612EFABCD;

        // Initialize inputs
        rx_payload_in = 48'h000000000000;
        rx_data_valid_in = 1'b0;

        // Reset the module
        $display("T=%0t: Starting reset...", $time);
        rst_n = 1'b0;
        #(CLK_PERIOD * 2); 
        rst_n = 1'b1;
        $display("T=%0t: Reset released.", $time);
        #(CLK_PERIOD);

        $display("T=%0t: Starting payload transmission. Expected: X=0xABCD, Y=0xEF12, Z=0x3456", $time);

        // Send the complete 48-bit payload in one clock cycle
        @(posedge clk);
        rx_payload_in = test_payload;
        rx_data_valid_in = 1'b1;
        $display("T=%0t: Sending 48-bit payload: 0x%h", $time, test_payload);
        
        // Deassert valid flag on the next clock cycle
        @(posedge clk);
//        rx_data_valid_in = 1'b0;
        
        // Wait a few cycles to check output
//        @(posedge clk);
        
        // --- 6. Verification ---
        $display("T=%0t: *** Verification ***", $time);
        if (packet_ready) begin
            $display("T=%0t: PASSED - packet_ready asserted correctly.", $time);
            if (x_axis_out == 16'hABCD && y_axis_out == 16'h12EF && z_axis_out == 16'h3456) begin
                $display("T=%0t: PASSED - Data assembled correctly.", $time);
                $display("T=%0t: X_axis: 0x%h, Y_axis: 0x%h, Z_axis: 0x%h", $time, x_axis_out, y_axis_out, z_axis_out);
            end else begin
                $display("T=%0t: FAILED - Data assembly incorrect.", $time);
                $display("T=%0t: Expected X=0xabcd, Y=0x12ef, Z=0x3456", $time);
                $display("T=%0t: Actual   X=0x%h, Y=0x%h, Z=0x%h", $time, x_axis_out, y_axis_out, z_axis_out);
            end
        end else begin
            $display("T=%0t: FAILED - packet_ready was NOT asserted.", $time);
        end
        
        $display("T=%0t: Test finished.", $time);
        $finish;
    end

endmodule