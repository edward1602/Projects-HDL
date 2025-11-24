//`timescale 1ns / 1ps

//module nrf_tx_test_core (
//    input wire clk,
//    input wire reset,
    
//    // SPI Interface
//    output reg spi_start,
//    output reg [7:0] spi_tx,
//    input wire [7:0] spi_rx,
//    input wire spi_busy,
    
//    // NRF Control
//    output reg ce,
//    output reg csn,
//    output reg [3:0] state_debug // LED hi?n th? Status
//);

//    // Các l?nh NRF
//    localparam CMD_W_REG      = 8'h20;
//    localparam CMD_W_PAYLOAD  = 8'hA0;
//    localparam CMD_FLUSH_TX   = 8'hE1; 
//    localparam CMD_NOP        = 8'hFF; 

//    // D? LI?U C? ??NH MU?N G?I (Thay ??i t?i ?ây)
//    localparam [7:0] FIXED_DATA = 8'h55; // 01010101 - D? ki?m tra bit l?i

//    reg [4:0] state;
//    reg [26:0] timer;
//    reg [2:0] idx;
//    reg [7:0] nrf_status; 

//    always @(posedge clk) begin
//        state_debug <= nrf_status[3:0];
        
//        if (reset) begin
//            state <= 0;
//            ce <= 0; csn <= 1; spi_start <= 0;
//            timer <= 0; idx <= 0;
//            nrf_status <= 0;
//        end else begin
//            spi_start <= 0;
            
//            case (state)
//                // 1. Wait 150ms Power On
//                0: if (timer < 15_000_000) timer <= timer + 1; else begin timer <= 0; state <= 1; end

//                // 2. FLUSH TX
//                1: if (!spi_busy) begin csn<=0; spi_tx <= CMD_FLUSH_TX; spi_start<=1; state<=2; end
//                2: if (!spi_busy) begin csn<=1; state<=3; end

//                // 3. Config (0x0E: PTX, PWR_UP, CRC 2byte)
//                3: if (!spi_busy) begin csn<=0; spi_tx <= CMD_W_REG | 8'h00; spi_start<=1; state<=4; end
//                4: if (!spi_busy) begin spi_tx <= 8'h0E; spi_start<=1; state<=5; end
//                5: if (!spi_busy) begin csn<=1; state<=6; end

//                // 4. RF Channel 2
//                6: if (!spi_busy) begin csn<=0; spi_tx <= CMD_W_REG | 8'h05; spi_start<=1; state<=7; end
//                7: if (!spi_busy) begin spi_tx <= 8'h02; spi_start<=1; state<=8; end
//                8: if (!spi_busy) begin csn<=1; state<=9; end

//                // 5. TX Address: 0xE7 E7 E7 E7 E7
//                9: if (!spi_busy) begin csn<=0; spi_tx <= CMD_W_REG | 8'h10; spi_start<=1; state<=10; idx<=0; end
//                10: if (!spi_busy) begin 
//                       spi_tx <= 8'hE7; spi_start<=1; 
//                       if (idx < 4) idx <= idx + 1; else state <= 11;
//                   end
//                11: if (!spi_busy) begin csn<=1; state<=12; end

//                // --- LOOP G?I ---
//                // ??i 1 giây (100,000,000 cycles @ 100MHz)
//                12: if (timer < 100_000_000) timer <= timer + 1; else begin timer <= 0; state <= 13; end

//                // ??c Status (Debug)
//                13: if (!spi_busy) begin csn<=0; spi_tx <= CMD_NOP; spi_start<=1; state<=14; end
//                14: if (!spi_busy) begin 
//                       nrf_status <= spi_rx; 
//                       csn<=1; state<=15; 
//                    end

//                // G?i L?nh Write Payload
//                15: if (!spi_busy) begin csn<=0; spi_tx <= CMD_W_PAYLOAD; spi_start<=1; state<=16; end
                
//                // G?i D? Li?u C? ??nh
//                16: if (!spi_busy) begin spi_tx <= FIXED_DATA; spi_start<=1; state<=17; end
                
//                // Kích xung CE ?? phát
//                17: if (!spi_busy) begin 
//                    csn<=1;
//                    ce<=1; 
//                    timer<=0; 
//                    state<=18; 
//                end
                
//                // Gi? CE 50us
//                18: if (timer < 5000) timer <= timer + 1; else begin 
//                    ce<=0;      // Kéo CE xu?ng th?p
//                    timer<=0; 
//                    state<=12;  // Quay l?i ??u vòng l?p ??i 1s
//                end

//            endcase
//        end
//    end
//endmodule

`timescale 1ns / 1ps

module nrf_tx_test_core (
    input wire clk,
    input wire reset,
    
    // SPI Interface
    output reg spi_start,
    output reg [7:0] spi_tx,
    input wire [7:0] spi_rx,
    input wire spi_busy,
    
    // NRF Control
    output reg ce,
    output reg csn,
    output reg [3:0] state_debug // LED hi?n th? Status
);

    // --- CÁC L?NH NRF24L01 ---
    localparam CMD_W_REG      = 8'h20;
    localparam CMD_W_PAYLOAD  = 8'hA0;
    localparam CMD_FLUSH_TX   = 8'hE1;
    localparam CMD_NOP        = 8'hFF; 
    
    // --- L?NH M?I THÊM VÀO ---
    // Ghi vào thanh ghi EN_AA (0x01)
    localparam CMD_W_REG_EN_AA   = 8'h21; 
    // Ghi vào thanh ghi RF_SETUP (0x06)
    localparam CMD_W_REG_RF_SETUP = 8'h26; 

    // D? LI?U C? ??NH MU?N G?I
    // Arduino ?ang config PayloadSize = 1, nên ta g?i 1 byte này
    localparam [7:0] FIXED_DATA = 8'h55; 

    reg [4:0] state;
    reg [26:0] timer;
    reg [2:0] idx;
    reg [7:0] nrf_status;

    always @(posedge clk) begin
        // Debug: Hi?n th? 4 bit th?p c?a thanh ghi Status ra LED
        state_debug <= nrf_status[3:0];

        if (reset) begin
            state <= 0;
            ce <= 0;
            csn <= 1; 
            spi_start <= 0;
            timer <= 0; 
            idx <= 0;
            nrf_status <= 0;
        end else begin
            spi_start <= 0;

            case (state)
                // ---------------------------------------------------------
                // 1. Wait 150ms Power On (Cho chip ?n ??nh)
                // ---------------------------------------------------------
                0: if (timer < 15_000_000) timer <= timer + 1;
                   else begin timer <= 0; state <= 1; end

                // ---------------------------------------------------------
                // 2. FLUSH TX (Xóa b? ??m c?)
                // ---------------------------------------------------------
                1: if (!spi_busy) begin csn<=0; spi_tx <= CMD_FLUSH_TX; spi_start<=1; state<=2; end
                2: if (!spi_busy) begin csn<=1; state<=3; end

                // ---------------------------------------------------------
                // 3. [M?I] T?T AUTO-ACK (EN_AA = 0x00)
                // ?? kh?p v?i code Arduino: radio.setAutoAck(false);
                // ---------------------------------------------------------
                3: if (!spi_busy) begin csn<=0; spi_tx <= CMD_W_REG_EN_AA; spi_start<=1; state<=4; end
                4: if (!spi_busy) begin spi_tx <= 8'h00; spi_start<=1; state<=5; end
                5: if (!spi_busy) begin csn<=1; state<=6; end

                // ---------------------------------------------------------
                // 4. [M?I] C?U HÌNH T?C ?? 250KBPS (RF_SETUP = 0x26)
                // Bit 5 (RF_DR_LOW) = 1, Bit 3 (RF_DR_HIGH) = 0 -> 250kbps
                // ?? kh?p v?i code Arduino: radio.setDataRate(RF24_250KBPS);
                // ---------------------------------------------------------
                6: if (!spi_busy) begin csn<=0; spi_tx <= CMD_W_REG_RF_SETUP; spi_start<=1; state<=7; end
                7: if (!spi_busy) begin spi_tx <= 8'h26; spi_start<=1; state<=8; end
                8: if (!spi_busy) begin csn<=1; state<=9; end

                // ---------------------------------------------------------
                // 5. CONFIG (0x0E: PTX, PWR_UP, CRC 2byte)
                // Register 0x00
                // ---------------------------------------------------------
                9: if (!spi_busy) begin csn<=0; spi_tx <= CMD_W_REG | 8'h00; spi_start<=1; state<=10; end
                10: if (!spi_busy) begin spi_tx <= 8'h0E; spi_start<=1; state<=11; end
                11: if (!spi_busy) begin csn<=1; state<=12; end

                // ---------------------------------------------------------
                // 6. RF Channel 2 (Register 0x05)
                // ---------------------------------------------------------
                12: if (!spi_busy) begin csn<=0; spi_tx <= CMD_W_REG | 8'h05; spi_start<=1; state<=13; end
                13: if (!spi_busy) begin spi_tx <= 8'h02; spi_start<=1; state<=14; end
                14: if (!spi_busy) begin csn<=1; state<=15; end

                // ---------------------------------------------------------
                // 7. TX Address: 0xE7 E7 E7 E7 E7 (Register 0x10)
                // ---------------------------------------------------------
                15: if (!spi_busy) begin 
                        csn<=0; 
                        spi_tx <= CMD_W_REG | 8'h10; 
                        spi_start<=1; 
                        state<=16; 
                        idx<=0; 
                    end
                16: if (!spi_busy) begin 
                        spi_tx <= 8'hE7;
                        spi_start<=1; 
                        // G?i ?? 5 byte ??a ch?
                        if (idx < 4) idx <= idx + 1; else state <= 17;
                    end
                17: if (!spi_busy) begin csn<=1; state<=18; end

                // =========================================================
                // VÒNG L?P G?I D? LI?U CHÍNH
                // =========================================================
                
                // 8. ??i 1 giây (100,000,000 cycles @ 100MHz)
                18: if (timer < 100_000_000) timer <= timer + 1;
                    else begin timer <= 0; state <= 19; end

                // 9. ??c Status (?? debug ra LED)
                19: if (!spi_busy) begin csn<=0; spi_tx <= CMD_NOP; spi_start<=1; state<=20; end
                20: if (!spi_busy) begin 
                        nrf_status <= spi_rx; 
                        csn<=1; 
                        state<=21; 
                    end

                // 10. G?i L?nh Write Payload
                21: if (!spi_busy) begin csn<=0; spi_tx <= CMD_W_PAYLOAD; spi_start<=1; state<=22; end
                
                // 11. G?i D? Li?u C? ??nh (1 Byte)
                22: if (!spi_busy) begin spi_tx <= FIXED_DATA; spi_start<=1; state<=23; end
                
                // 12. Kích xung CE ?? phát sóng
                23: if (!spi_busy) begin 
                        csn<=1; // K?t thúc l?nh SPI tr??c
                        ce<=1;  // B?t CE
                        timer<=0; 
                        state<=24; 
                    end
                
                // 13. Gi? CE 50us (T?i thi?u 10us)
                24: if (timer < 5000) timer <= timer + 1;
                    else begin 
                        ce<=0;      // Kéo CE xu?ng
                        timer<=0;
                        state<=18;  // Quay l?i ??u vòng l?p ??i 1s
                    end

                default: state <= 0;
            endcase
        end
    end
endmodule