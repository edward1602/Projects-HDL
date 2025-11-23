`timescale 1ns / 1ps

// Testbench for the spi_master module, now supporting selective test execution.
module tb_spi_master;

    // ----------------------------------------------------
    // 1. PARAMETERS & CONSTANTS
    // ----------------------------------------------------
    parameter CLK_DIV = 50; 
    parameter CLK_PERIOD = 10; 
    
    // Test Data Patterns
    parameter DATA_TX_PATTERN_1 = 8'h5A; 
    parameter DATA_RX_EXPECTED_1 = 8'hC3; 
    parameter DATA_TX_PATTERN_2 = 8'hAA; 
    parameter DATA_RX_EXPECTED_2 = 8'h3C; 
    
    parameter TEST_CASE_ID = 3;
    
    // ----------------------------------------------------
    // 2. SIGNALS & DUT Instantiation
    // ----------------------------------------------------
    // DUT Inputs
    reg clk;
    reg reset;
    reg start;
    reg [7:0] data_tx;
    reg miso; // Master In Slave Out
    
    // DUT Outputs
    wire [7:0] data_rx;
    wire busy;
    wire sck;
    wire mosi; // Master Out Slave In
    
    // Internal variables for slave logic
    reg [7:0] slave_shift_reg;
    reg [3:0] slave_bit_index;
    
    
    // Device Under Test (DUT)
    spi_master #(.CLK_DIV(CLK_DIV)) DUT (
        .clk(clk),
        .reset(reset),
        .start(start),
        .data_tx(data_tx),
        .data_rx(data_rx),
        .busy(busy),
        .sck(sck),
        .mosi(mosi),
        .miso(miso)
    );
    
    
    // ----------------------------------------------------
    // 3. Clock Generation
    // ----------------------------------------------------
    always begin
        # (CLK_PERIOD / 2) clk = ~clk;
    end
    
    
    // ----------------------------------------------------
    // 4. COMMON TASK: Single SPI Transfer Transaction
    // ----------------------------------------------------
    // This task executes a single 8-bit SPI transaction (CPOL=0, CPHA=0).
    task run_transfer;
        input [7:0] tx_data_in;
        input [7:0] rx_data_expected_in;
        begin
            $display("\n=======================================================");
            $display("[%0t] STARTING TRANSFER: TX=%h, Expected RX=%h", $time, tx_data_in, rx_data_expected_in);
            $display("=======================================================");
            
            // 1. Setup Master and Slave
            data_tx = tx_data_in;
            slave_shift_reg = rx_data_expected_in;
            slave_bit_index = 0;
            start = 1;
            
            // CRUCIAL for CPHA=0: Set the first MISO bit (MSB) before the first SCK rising edge.
            miso <= rx_data_expected_in[7]; 
            
            @(posedge clk) #1;
            start = 0; 
            
            // Wait for BUSY to assert
            wait(busy == 1);
            $display("[%0t] Master is BUSY. Starting 8-bit loop.", $time);
            
            // 2. 8-Bit Transfer Loop 
            while (slave_bit_index < 8) begin
                
                // --- Step A: Wait for Posedge SCK (Master Samples MISO) ---
                @(posedge sck) begin
                    $display("[%0t] Posedge SCK (Bit %0d): MOSI (TX Master) = %b, MISO (RX Slave) = %b, Expected_RX_Bit = %b", 
                             $time, slave_bit_index, mosi, miso, slave_shift_reg[7 - slave_bit_index]);
                             
                    slave_bit_index <= slave_bit_index + 1; 
                end
                
                // --- Step B: Wait for Negedge SCK (Slave Sets MISO for next bit) ---
                @(negedge sck) begin
                    #1; 
                    
                    // Slave sets MISO for the NEXT bit (before the next posedge SCK)
                    if (slave_bit_index < 8) begin
                        miso <= slave_shift_reg[7 - slave_bit_index]; 
                    end
                end
            end
            
            // 3. Wait for Transaction End
            wait(busy == 0);
            $display("[%0t] Transfer Complete. Master is IDLE. SCK=%b.", $time, sck);
            
            // 4. Verification
            if (data_rx === slave_shift_reg) begin
                $display("--- VERIFICATION SUCCESS ---");
                $display("RX Data: %h (Matches Expected %h)", data_rx, slave_shift_reg);
            end else begin
                $error("--- VERIFICATION FAILED ---");
                $error("RX Data: %h (DOES NOT MATCH Expected %h)", data_rx, slave_shift_reg);
            end
        end
    endtask


    // ----------------------------------------------------
    // 5. MAIN TEST SCENARIOS (Selective Execution)
    // ----------------------------------------------------
    initial begin
        $display("----------------------------------------");
        $display("STARTING SELECTIVE SPI MASTER TESTBENCH");
        $display("Selected Test Case ID: %0d", TEST_CASE_ID);
        $display("----------------------------------------");
        
        // 1. Common Initialization and Reset
        clk = 0;
        reset = 1;
        start = 0;
        data_tx = 8'h00; 
        miso = 1'bZ; 
        
        # (CLK_PERIOD * 2) @(posedge clk);
        reset = 0; // Release Reset
        $display("[%0t] System Reset Released. Master is in IDLE state.", $time);
        
        
        // =======================================================================
        // EXECUTION CONTROL BLOCK
        // =======================================================================

        if (TEST_CASE_ID == 1) begin
            $display("Running Test Case 1: Standard Transfer (5A <-> C3)");
            run_transfer(DATA_TX_PATTERN_1, DATA_RX_EXPECTED_1);
        end 
        
        else if (TEST_CASE_ID == 2) begin
            $display("Running Test Case 2: Standard Transfer (AA <-> 3C)");
            run_transfer(DATA_TX_PATTERN_2, DATA_RX_EXPECTED_2);
        end
        
        else if (TEST_CASE_ID == 3) begin
            $display("Running Test Case 3: Reset During Transfer Test");
            
            // a. Start transfer
            data_tx = 8'h12;
            slave_shift_reg = 8'hFE;
            slave_bit_index = 0;
            start = 1;
            miso <= slave_shift_reg[7]; // Initial MISO set
            @(posedge clk) #1;
            start = 0;
            
            wait(busy == 1);
            $display("[%0t] Transfer started. Waiting for 3 bits to transfer...", $time);
            
            // b. Wait for first few SCK cycles (e.g., 3 bits)
            repeat (3) @(posedge sck);
            
            // c. Assert Reset
            $display("[%0t] *** ASSERTING HARD RESET DURING TRANSFER ***", $time);
            reset = 1;
            
            // d. Wait for a few clock cycles and check state
            # (CLK_PERIOD * 5) @(posedge clk);
            if (busy == 0 && sck == 0) begin
                $display("[%0t] RESET SUCCESSFUL: Busy=%b and SCK=%b are reset correctly.", $time, busy, sck);
            end else begin
                 $error("[%0t] RESET FAILED: Busy=%b or SCK=%b did not reset.", $time, busy, sck);
            end
            
            // e. Release Reset and confirm functionality is restored
            @(posedge clk) #1;
            reset = 0;
            $display("[%0t] Reset released. Running final check transfer (CD <-> AB).", $time);
            
            # (CLK_PERIOD * 10) @(posedge clk); 
            run_transfer(8'hCD, 8'hAB);
        end
        
        else begin
            $display("ERROR: Invalid TEST_CASE_ID (%0d). Please set TEST_CASE_ID to 1, 2, or 3.", TEST_CASE_ID);
        end
        
        // -----------------------------------------------------------------------
        
        // Finalize simulation
        $display("\n[%0t] Simulation finished.", $time);
        #100 $finish;
    end
    
    // VCD Dump for Waveform viewing
    initial begin
        $dumpfile("spi_master.vcd");
        $dumpvars(0, tb_spi_master);
    end

endmodule