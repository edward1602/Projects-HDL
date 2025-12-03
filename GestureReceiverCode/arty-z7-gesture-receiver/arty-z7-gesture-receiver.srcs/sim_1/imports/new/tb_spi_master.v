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
    // 4. K?ch b?n Test
    // ----------------------------------------------------
    initial begin
        $display("--- Begin Testbench spi_master ---");
        clk = 1'b0;
        rst_n = 1'b0;
        start_transfer = 1'b0;
        data_in = 8'h00;
        spi_miso = 1'b1;
        
        // Reset
        #100; 
        rst_n = 1'b1;
        $display("Reset.");

        // Thi?t l?p d? li?u
        data_in = TEST_DATA_TX;
        expected_data_out = TEST_DATA_RX;
        
        // B?t ??u truy?n
        #10 start_transfer = 1'b1;
        #10 start_transfer = 1'b0; 
        
        $display("Transfer TX=%b", data_in);

        // M� ph?ng 8 bit truy?n/nh?n
        for (i = 0; i < 8; i = i + 1) begin
            @(posedge spi_sck) begin
                // Slave ??a d? li?u ra MISO
                spi_miso <= expected_data_out[7 - i];

                // Ki?m tra MOSI c� ?�ng kh�ng
                if (spi_mosi !== TEST_DATA_TX[7 - i]) begin
                    $display("-> LOI MOSI: Bit %0d, MOSI=%b, mong ??i=%b", 
                              i, spi_mosi, TEST_DATA_TX[7 - i]);
                end else begin
                    $display("-> DUNG MOSI: Bit %0d, MOSI=%b", i, spi_mosi);
                end

                // In th�ng tin RX
                $display("@%0t: Bit %0d TX=%b, RX(MISO)=%b", 
                          $time, i, spi_mosi, spi_miso);
            end
        end
        
        // Ch? k?t th�c truy?n
        @(posedge transfer_done);
        $display("--- K?t th�c truy?n. Th?i gian: %0t ---", $time);

        // Ki?m tra d? li?u nh?n
        if (data_out == expected_data_out) begin
            $display("-> THANH CONG RX: data_out=%b kh?p v?i mong ??i=%b", 
                      data_out, expected_data_out);
        end else begin
            $display("-> THAT BAI RX: data_out=%b, mong ??i=%b", 
                      data_out, exp ected_data_out);
        end
        
        #100 $finish; 
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
    
    // ----------------------------------------------------
    // 7. Waveform Dump
    // ----------------------------------------------------
    initial begin
        $dumpfile("tb_spi_master.vcd");
        $dumpvars(0, tb_spi_master);
    end

endmodule