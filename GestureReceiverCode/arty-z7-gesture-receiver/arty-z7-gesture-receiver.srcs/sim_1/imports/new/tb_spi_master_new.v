`timescale 1ns / 1ps

module tb_spi_master;

    // ----------------------------------------------------
    // 1. Testbench Signal Declarations
    // ----------------------------------------------------
    reg clk;
    reg rst_n;
    
    reg [7:0] spi_clk_div; 
    
    reg start_transfer;
    reg [7:0] data_in;
    reg spi_miso;

    wire transfer_done;
    wire [7:0] data_out;
    wire spi_sck;
    wire spi_mosi;
    
    // Test parameters
    parameter CLK_PERIOD = 10; // 100MHz clock
    parameter TEST_DATA_TX = 8'hA5; // Test data to transmit (10100101)
    parameter TEST_DATA_RX = 8'h5A; // Test data to receive (01011010)
    
    // Internal variables
    reg [7:0] expected_rx_data;
    reg [7:0] miso_shift_reg;
    integer bit_count;
    integer test_count;
    integer error_count;

    // ----------------------------------------------------
    // 2. DUT Instantiation
    // ----------------------------------------------------
    spi_master DUT (
        .clk(clk),
        .rst_n(rst_n),
        .spi_clk_div(spi_clk_div),
        
        .start_transfer(start_transfer),
        .transfer_done(transfer_done),
        .data_in(data_in),
        .data_out(data_out),

        .spi_sck(spi_sck),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso)
    );

    // ----------------------------------------------------
    // 3. Clock Generation (100 MHz)
    // ----------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // ----------------------------------------------------
    // 4. Test Scenarios
    // ----------------------------------------------------
    initial begin
        $display("=== SPI Master Testbench Started ===");
        
        // Initialize signals
        rst_n = 0;
        start_transfer = 0;
        data_in = 0;
        spi_miso = 0;
        spi_clk_div = 8'd4; // Divide by 4 for faster simulation
        test_count = 0;
        error_count = 0;
        
        // Reset sequence
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);
        $display("[%0t] Reset completed", $time);

        // Test 1: Basic SPI transfer
        test_spi_transfer(TEST_DATA_TX, TEST_DATA_RX);
        
        // Test 2: All zeros
        test_spi_transfer(8'h00, 8'hFF);
        
        // Test 3: All ones
        test_spi_transfer(8'hFF, 8'h00);
        
        // Test 4: Alternating pattern
        test_spi_transfer(8'hAA, 8'h55);
        
        // Test 5: Different clock divider
        spi_clk_div = 8'd8;
        test_spi_transfer(8'h3C, 8'hC3);
        
        // Test summary
        $display("\n=== Test Summary ===");
        $display("Total tests: %0d", test_count);
        $display("Errors: %0d", error_count);
        if (error_count == 0) begin
            $display("*** ALL TESTS PASSED ***");
        end else begin
            $display("*** %0d TESTS FAILED ***", error_count);
        end
        
        #100;
        $finish;
    end
    
    // ----------------------------------------------------
    // 5. Task: Test SPI Transfer
    // ----------------------------------------------------
    task test_spi_transfer;
        input [7:0] tx_data;
        input [7:0] rx_data;
        begin
            test_count = test_count + 1;
            $display("\n--- Test %0d: TX=0x%h, Expected RX=0x%h ---", test_count, tx_data, rx_data);
            
            // Setup test data
            data_in = tx_data;
            expected_rx_data = rx_data;
            miso_shift_reg = rx_data;
            bit_count = 0;
            
            // Start transfer
            @(posedge clk);
            start_transfer = 1;
            @(posedge clk);
            start_transfer = 0;
            
            $display("[%0t] Transfer started", $time);
            
            // Wait for transfer completion
            @(posedge transfer_done);
            
            // Verify results
            if (data_out == expected_rx_data) begin
                $display("[%0t] ✓ PASS: RX data correct (0x%h)", $time, data_out);
            end else begin
                $display("[%0t] ✗ FAIL: RX data incorrect (got 0x%h, expected 0x%h)", 
                         $time, data_out, expected_rx_data);
                error_count = error_count + 1;
            end
            
            repeat(5) @(posedge clk); // Wait between tests
        end
    endtask
    
    // ----------------------------------------------------
    // 6. MISO Simulation (Slave Response)
    // ----------------------------------------------------
    always @(posedge spi_sck or negedge rst_n) begin
        if (!rst_n) begin
            bit_count <= 0;
        end else begin
            // Send MSB first on MISO
            spi_miso <= miso_shift_reg[7-bit_count];
            $display("[%0t] SCK rising: Bit %0d, MOSI=%b, MISO=%b", 
                     $time, bit_count, spi_mosi, miso_shift_reg[7-bit_count]);
            bit_count <= bit_count + 1;
        end
    end
    
    // Reset bit counter when not transmitting
    always @(negedge spi_sck or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled above
        end else begin
            // Optional: Add additional logic on falling edge if needed
        end
    end
    
    // Reset bit counter when transfer starts
    always @(posedge start_transfer) begin
        bit_count <= 0;
    end
    
    // ----------------------------------------------------
    // 7. Monitors and Assertions
    // ----------------------------------------------------
    
    // Monitor SCK frequency
    real sck_period;
    time last_sck_time = 0;
    
    always @(posedge spi_sck) begin
        if (last_sck_time != 0) begin
            sck_period = $time - last_sck_time;
        end
        last_sck_time = $time;
    end
    
    // Monitor transfer duration
    time transfer_start_time;
    time transfer_end_time;
    
    always @(posedge start_transfer) begin
        transfer_start_time = $time;
    end
    
    always @(posedge transfer_done) begin
        transfer_end_time = $time;
        $display("[%0t] Transfer completed in %0t ns", $time, transfer_end_time - transfer_start_time);
    end
    
    // ----------------------------------------------------
    // 8. Waveform Dump
    // ----------------------------------------------------
    initial begin
        $dumpfile("tb_spi_master.vcd");
        $dumpvars(0, tb_spi_master);
    end

endmodule