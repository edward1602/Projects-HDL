`timescale 1ns / 1ps

module spi_master_tb;

    // ----------------------------------------------------
    // 1. Khai báo tín hi?u Testbench
    // ----------------------------------------------------
    reg clk;
    reg rst_n;
    
    reg [7:0] spi_clk_div = 8'd8; 
    
    reg start_transfer;
    reg [7:0] data_in;
    reg spi_miso;

    wire transfer_done;
    wire [7:0] data_out;
    wire spi_sck;
    wire spi_mosi;
    
    parameter TEST_DATA_TX = 8'b10101111; // d? li?u master g?i
    parameter TEST_DATA_RX = 8'b01010000; // d? li?u slave tr? v?
    
    reg [7:0] expected_data_out;
    integer i;

    // ----------------------------------------------------
    // 2. Kh?i t?o DUT
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
    // 3. T?o Clock 100 MHz
    // ----------------------------------------------------
    always #5 clk = ~clk; 

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

        // Mô ph?ng 8 bit truy?n/nh?n
        for (i = 0; i < 8; i = i + 1) begin
            @(posedge spi_sck) begin
                // Slave ??a d? li?u ra MISO
                spi_miso <= expected_data_out[7 - i];

                // Ki?m tra MOSI có ?úng không
                if (spi_mosi !== TEST_DATA_TX[7 - i]) begin
                    $display("-> LOI MOSI: Bit %0d, MOSI=%b, mong ??i=%b", 
                              i, spi_mosi, TEST_DATA_TX[7 - i]);
                end else begin
                    $display("-> DUNG MOSI: Bit %0d, MOSI=%b", i, spi_mosi);
                end

                // In thông tin RX
                $display("@%0t: Bit %0d TX=%b, RX(MISO)=%b", 
                          $time, i, spi_mosi, spi_miso);
            end
        end
        
        // Ch? k?t thúc truy?n
        @(posedge transfer_done);
        $display("--- K?t thúc truy?n. Th?i gian: %0t ---", $time);

        // Ki?m tra d? li?u nh?n
        if (data_out == expected_data_out) begin
            $display("-> THANH CONG RX: data_out=%b kh?p v?i mong ??i=%b", 
                      data_out, expected_data_out);
        end else begin
            $display("-> THAT BAI RX: data_out=%b, mong ??i=%b", 
                      data_out, expected_data_out);
        end
        
        #100 $finish; 
    end
    
    // ----------------------------------------------------
    // 5. Ghi sóng (Tùy ch?n)
    // ----------------------------------------------------
    initial begin
        $dumpfile("spi_master.vcd");
        $dumpvars(0, spi_master_tb);
    end

endmodule