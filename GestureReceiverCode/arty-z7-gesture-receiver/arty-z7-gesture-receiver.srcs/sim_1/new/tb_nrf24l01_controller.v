`timescale 1ns / 1ps
module tb_nrf24l01_controller;
    // ====================================================================
    // 1. TEST CASE SELECTOR (gi? nguyên c?a b?n - c?c hay!)
    // ====================================================================
    parameter TEST_CASE_SELECT = 4;
    // 1: Standard | 2: Zero | 3: Max Positive | 4: Boundary Test
    // ====================================================================
    // 2. Inputs & Outputs
    // ====================================================================
    reg clk = 0;
    reg reset = 1;
    reg [7:0] spi_rx;
    wire spi_busy;
    wire [7:0] payload_0, payload_1, payload_2, payload_3, payload_4, payload_5;
    wire data_ready;
    wire spi_start;
    wire [7:0] spi_tx;
    wire ce, csn;
    reg nrf_irq = 1; // IRQ m?c ??nh high (không có gói tin)
    // Instantiate UUT - b?n hoàn ch?nh c?a mình
    nrf24l01_controller #(
        .USE_IRQ(0), // B?t IRQ ?? test t?i ?u nh?t
        .DATA_RATE("250K") // Có th? ??i thành "1M" ho?c "2M"
    ) uut (
        .clk(clk),
        .reset(reset),
        .nrf_irq(nrf_irq),
        .payload_0(payload_0),
        .payload_1(payload_1),
        .payload_2(payload_2),
        .payload_3(payload_3),
        .payload_4(payload_4),
        .payload_5(payload_5),
        .data_ready(data_ready),
        .spi_start(spi_start),
        .spi_tx(spi_tx),
        .spi_rx(spi_rx),
        .spi_busy(spi_busy),
        .ce(ce),
        .csn(csn)
    );
    always #5 clk = ~clk; // 100 MHz
    // ====================================================================
    // 3. Expected Data Setup (gi? nguyên logic c? c?a b?n)
    // ====================================================================
    reg [7:0] expected_p0, expected_p1; // X low, X high
    reg [7:0] expected_p2, expected_p3; // Y low, Y high
    reg [7:0] expected_p4, expected_p5; // Z low, Z high
    initial begin
        case (TEST_CASE_SELECT)
            1: begin
                {expected_p1, expected_p0} = 16'd512; // X
                {expected_p3, expected_p2} = 16'd600; // Y
                {expected_p5, expected_p4} = 16'd400; // Z
            end
            2: begin
                expected_p0 = 0; expected_p1 = 0;
                expected_p2 = 0; expected_p3 = 0;
                expected_p4 = 0; expected_p5 = 0;
            end
            3: begin
                {expected_p1, expected_p0} = 16'h7FFF;
                {expected_p3, expected_p2} = 16'h7FFF;
                {expected_p5, expected_p4} = 16'h7FFF;
            end
            4: begin
                {expected_p1, expected_p0} = 16'h01FF; // 511
                {expected_p3, expected_p2} = 16'h0100; // 256
                {expected_p5, expected_p4} = 16'h00FF; // 255
            end
            default: begin
                expected_p0 = 0; expected_p1 = 0; expected_p2 = 0;
                expected_p3 = 0; expected_p4 = 0; expected_p5 = 0;
            end
        endcase
    end
  
    // ====================================================================
    // 4. Smart NRF24L01 Slave Model + IRQ Simulation (S?A RACE CONDITION)
    reg busy_internal = 0;
    reg [15:0] busy_cnt = 0;
    reg [2:0] payload_idx = 0;
    reg reading_payload = 0; // Flag ?ang trong quá trình ??c payload
    assign spi_busy = spi_start | busy_internal;
    // Payload memory
    reg [7:0] tx_payload_mem [0:5];
    initial begin
        #2;
        tx_payload_mem[0] = expected_p0;
        tx_payload_mem[1] = expected_p1;
        tx_payload_mem[2] = expected_p2;
        tx_payload_mem[3] = expected_p3;
        tx_payload_mem[4] = expected_p4;
        tx_payload_mem[5] = expected_p5;
    end
    always @(posedge clk) begin
        if (reset) begin
            busy_internal <= 0;
            busy_cnt <= 0;
            spi_rx <= 8'h00;
            nrf_irq <= 1;
            payload_idx <= 0;
            reading_payload <= 0;
        end else begin
            // === B?t ??u transaction SPI ===
            if (spi_start && !busy_internal) begin
                busy_internal <= 1;
                busy_cnt <= 20; // ~200ns t?i 100MHz (?? cho 1 byte @ 2MHz)
                // Phân tích l?nh t? controller và set spi_rx ngay ?? tránh race
                case (spi_tx)
                    8'h61: begin // R_RX_PAYLOAD
                        spi_rx <= 8'h4E; // Status byte có RX_DR=1
                        reading_payload <= 1;
                        payload_idx <= 0;
                        nrf_irq <= 0;
                    end
                    8'hFF: begin // NOP ph?i tr? v? RX_DR=1 !!!
                        spi_rx <= 8'h4E; // 0x4E = 01001110 bit6=1 có d? li?u!
                    end
                    8'hE2: begin // FLUSH_RX
                        spi_rx <= 8'h00;
                        nrf_irq <= 1;
                    end
                    8'h27: begin // W_REGISTER | STATUS
                        spi_rx <= 8'h00;
                    end
                    8'h20, 8'h21, 8'h23, 8'h25, 8'h26, 8'h2A, 8'h31: begin
                        spi_rx <= 8'h00;
                    end
                    8'h00: begin // Dummy byte cho payload (set spi_rx ngay ?? tránh race)
                        if (reading_payload && payload_idx < 6) begin
                            spi_rx <= tx_payload_mem[payload_idx];
                            payload_idx <= payload_idx + 1;
                        end else begin
                            spi_rx <= 8'h00;
                        end
                    end
                    default: begin
                        spi_rx <= 8'h00; // Các l?nh khác
                    end
                endcase
            end
            // === K?t thúc transaction ===
            if (busy_cnt > 0) begin
                busy_cnt <= busy_cnt - 1;
                if (busy_cnt == 1) begin
                    busy_internal <= 0;
                    // N?u v?a ??c xong payload ? chu?n b? cho l?n sau
                    if (reading_payload && payload_idx >= 6) begin
                        reading_payload <= 0;
                        payload_idx <= 0;
                    end
                end
            end
        end
    end
    // ====================================================================
    // 5. Data Ready Monitor
    // ====================================================================
    reg data_ready_seen = 0;
    always @(posedge clk) begin
        if (data_ready) data_ready_seen = 1;
    end
    // ====================================================================
    // 6. Main Test Sequence
    // ====================================================================
    initial begin
        $display("========================================");
        $display(" NRF24L01 CONTROLLER TESTBENCH - CASE %0d", TEST_CASE_SELECT);
        $display("========================================");
        #50 reset = 0;
        // Force b? qua delay trong S_PWR_ON_DELAY
        #100; // Ch? tí sau reset
        force uut.delay_cnt = 24'd10_000_001; // Force v??t ng??ng 10_000_000
        #10; // Ch? FSM update
        release uut.delay_cnt;
        // Force b? qua delay trong S_DELAY_2MS
        #100; // Ch? FSM ?i ??n S_DELAY_2MS
        force uut.delay_cnt = 24'd200_001; // Force v??t ng??ng 200_000
        #10; // Ch? FSM update
        release uut.delay_cnt;
        // Ch? FSM ?i ??n end và data_ready lên (t?ng th?i gian ch? ?? an toàn)
        #1_000_000; // Ch? 1ms cho config + receive (?? cho sim, n?u v?n fail t?ng lên #10_000_000)

        if (data_ready_seen) begin
            if (payload_0 === expected_p0 && payload_1 === expected_p1 &&
                payload_2 === expected_p2 && payload_3 === expected_p3 &&
                payload_4 === expected_p4 && payload_5 === expected_p5) begin
                $display("\n >>> TEST PASSED! <<<");
                $display(" Expected: %h %h %h %h %h %h", expected_p0, expected_p1,
                         expected_p2, expected_p3, expected_p4, expected_p5);
                $display(" Received: %h %h %h %h %h %h\n", payload_0, payload_1,
                                             payload_2, payload_3, payload_4, payload_5);
            end else begin
                $display("\n >>> TEST FAILED - DATA MISMATCH <<<");
                $display(" Expected: %h %h %h %h %h %h", expected_p0, expected_p1,
                         expected_p2, expected_p3, expected_p4, expected_p5);
                $display(" Received: %h %h %h %h %h %h\n", payload_0, payload_1,
                         payload_2, payload_3, payload_4, payload_5);
            end
        end else begin
            $display("\n >>> TEST FAILED - data_ready never asserted! <<<\n");
        end
        $display("Simulation finished.");
        $finish;
    end
    // Optional: Dump waveform
    initial begin
        $dumpfile("nrf24l01_tb.vcd");
        $dumpvars(0, tb_nrf24l01_controller);
    end
endmodule