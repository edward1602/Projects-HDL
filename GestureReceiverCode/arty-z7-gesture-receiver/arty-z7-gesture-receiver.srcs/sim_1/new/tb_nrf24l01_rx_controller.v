`timescale 1ns / 1ps

module tb_nrf24l01_rx_controller;

    // Testbench signals
    reg clk;
    reg rst_n;
    reg start_rx;
    wire rx_ready;
    wire nrf_ce;
    wire nrf_csn;
    reg nrf_irq;
    wire spi_sck;
    wire spi_mosi;
    reg spi_miso;
    wire [47:0] rx_payload;
    wire payload_ready;
    
    parameter CLK_PERIOD = 10; // 100MHz clock
    
    // DUT instantiation
    nrf24l01_rx_controller dut (
        .clk(clk),
        .rst_n(rst_n),
        .start_rx(start_rx),
        .rx_ready(rx_ready),
        .nrf_ce(nrf_ce),
        .nrf_csn(nrf_csn),
        .nrf_irq(nrf_irq),
        .spi_sck(spi_sck),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .rx_payload(rx_payload),
        .payload_ready(payload_ready)
    );
    
    // Clock generation
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;
    
    // Test stimulus
    initial begin
        $display("=== NRF24L01 Simple RX Controller Test ===");
        
        // Initialize signals
        rst_n = 0;
        start_rx = 0;
        nrf_irq = 1; // Active low
        spi_miso = 0;
        
        // Reset sequence
        #100;
        rst_n = 1;
        #50;
        
        $display("[%0t] Reset completed", $time);
        
        // Start RX operation
        start_rx = 1;
        #10;
        start_rx = 0;
        
        $display("[%0t] RX start issued", $time);
        
        // Wait for RX ready
        $display("[%0t] Waiting for RX ready...", $time);
        wait(rx_ready == 1'b1);
        $display("[%0t] ✓ RX Ready detected!", $time);
        
        // Wait a bit more then simulate data reception
        #10000;
        $display("[%0t] Simulating gesture data reception...", $time);
        nrf_irq = 0; // Assert IRQ (data ready)
        
        // Wait for payload processing
        wait(payload_ready == 1'b1);
        $display("[%0t] ✓ PAYLOAD RECEIVED!", $time);
        $display("    Raw payload: 0x%012h", rx_payload);
        
        // Extract gesture data (Little-Endian format)
        $display("    X-axis: 0x%04h (%0d)", {rx_payload[15:8], rx_payload[7:0]}, $signed({rx_payload[15:8], rx_payload[7:0]}));
        $display("    Y-axis: 0x%04h (%0d)", {rx_payload[31:24], rx_payload[23:16]}, $signed({rx_payload[31:24], rx_payload[23:16]}));
        $display("    Z-axis: 0x%04h (%0d)", {rx_payload[47:40], rx_payload[39:32]}, $signed({rx_payload[47:40], rx_payload[39:32]}));
        
        nrf_irq = 1; // Deassert IRQ
        
        #10000;
        $display("[%0t] Test completed", $time);
        $finish;
    end
    
    // SPI slave simulation with gesture test data
    reg [3:0] spi_counter;
    reg [2:0] payload_byte_sim;
    
    // Test gesture data: X=0x1234, Y=0x5678, Z=0x9ABC (Little-Endian)
    reg [7:0] test_payload [0:5];
    initial begin
        test_payload[0] = 8'h34; // X low byte
        test_payload[1] = 8'h12; // X high byte  
        test_payload[2] = 8'h78; // Y low byte
        test_payload[3] = 8'h56; // Y high byte
        test_payload[4] = 8'hBC; // Z low byte
        test_payload[5] = 8'h9A; // Z high byte
    end
    
    always @(posedge spi_sck or posedge nrf_csn) begin
        if (nrf_csn) begin
            spi_counter <= 0;
            payload_byte_sim <= 0;
            spi_miso <= 0;
        end else begin
            spi_counter <= spi_counter + 1;
            
            // During payload read, provide test data
            if (!nrf_irq && spi_counter >= 8) begin // After command byte
                spi_miso <= test_payload[payload_byte_sim][7-spi_counter[2:0]];
                if (spi_counter[2:0] == 7) begin
                    if (payload_byte_sim < 5)
                        payload_byte_sim <= payload_byte_sim + 1;
                end
            end else begin
                spi_miso <= spi_counter[0]; // Default alternating pattern
            end
        end
    end
    
    // Monitor key signals  
    always @(posedge nrf_ce) begin
        $display("[%0t] ✓ NRF_CE asserted - RX mode active", $time);
    end
    
    always @(negedge nrf_ce) begin
        $display("[%0t] NRF_CE deasserted", $time);
    end
    
    // Monitor state changes
    always @(dut.current_state) begin
        $display("[%0t] State: %0d", $time, dut.current_state);
    end
    
    always @(negedge nrf_csn) begin
        $display("[%0t] SPI transaction started", $time);
    end
    
    always @(posedge nrf_csn) begin
        $display("[%0t] SPI transaction ended", $time);
    end
    
    always @(posedge payload_ready) begin
        $display("[%0t] Payload ready: 0x%h", $time, rx_payload);
    end
    
    // Timeout
    initial begin
        #300000000; // 300ms timeout to see full initialization
        $display("[%0t] *** TIMEOUT - Final state: %0d ***", $time, dut.current_state);
        $display("rx_ready: %b, nrf_ce: %b", rx_ready, nrf_ce);
        $finish;
    end

endmodule