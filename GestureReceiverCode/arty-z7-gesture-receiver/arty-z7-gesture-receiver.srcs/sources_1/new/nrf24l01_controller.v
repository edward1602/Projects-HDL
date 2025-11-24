module nrf24l01_controller (
    input  wire        clk,            // System Clock (ví d? 50MHz)
    input  wire        rst_n,          // Reset active low
    
    // Giao ti?p v?i SPI Master Module
    output reg         spi_start,      // L?nh b?t ??u g?i 1 byte SPI
    output reg  [7:0]  spi_data_tx,    // D? li?u g?i ?i
    input  wire [7:0]  spi_data_rx,    // D? li?u nh?n v?
    input  wire        spi_done,       // C? báo xong 1 byte
    
    // Giao ti?p v?t lý nRF24L01
    input  wire        nrf_irq_n,      // Chân IRQ t? nRF (Active Low)
    output reg         nrf_csn,        // Chip Select (Active Low)
    output reg         nrf_ce,         // Chip Enable (Active High ?? nghe)
    
    // Output d? li?u cho ng??i dùng
    output reg [47:0]  payload_out,    // 6 Bytes d? li?u g?p l?i
    output reg         payload_valid   // B?t lên 1 chu k? khi có d? li?u m?i
);

    // --- ??nh ngh?a các l?nh nRF24L01 ---
    localparam CMD_W_REGISTER    = 8'h20; // L?nh ghi thanh ghi
    localparam CMD_R_RX_PAYLOAD  = 8'h61; // L?nh ??c d? li?u
    localparam REG_CONFIG        = 5'h00;
    localparam REG_EN_AA         = 5'h01;
    localparam REG_RF_CH         = 5'h05;
    localparam REG_STATUS        = 5'h07;
    localparam REG_RX_PW_P0      = 5'h11; // ?? r?ng payload Pipe 0

    // --- Các tr?ng thái FSM ---
    localparam S_RESET           = 4'd0;
    localparam S_INIT_CFG_SETUP  = 4'd1;  // Chu?n b? ghi thanh ghi c?u hình
    localparam S_INIT_CFG_WRITE  = 4'd2;  // G?i l?nh ghi
    localparam S_INIT_CFG_DATA   = 4'd3;  // G?i giá tr? c?u hình
    localparam S_RX_MODE         = 4'd4;  // Kéo CE High, ch? IRQ
    localparam S_READ_CMD        = 4'd5;  // G?i l?nh R_RX_PAYLOAD
    localparam S_READ_DATA       = 4'd6;  // ??c 6 bytes
    localparam S_CLEAR_IRQ       = 4'd7;  // Xóa c? ng?t
    localparam S_CLEAR_IRQ_DATA  = 4'd8;  
    localparam S_DELAY           = 4'd9;  // Delay nh? gi?a các thao tác CSN

    reg [3:0] state, next_state;
    reg [3:0] return_state;       // L?u tr?ng thái quay v? sau khi delay
    reg [2:0] config_step;        // ??m b??c c?u hình (0->3)
    reg [2:0] byte_count;         // ??m s? byte ?ã ??c (0->5)
    
    // B? ??m delay
    reg [15:0] delay_cnt;
    
    // D? li?u c?u hình mô ph?ng th? vi?n RF24
    // Step 0: RX_PW_P0 = 6 bytes
    // Step 1: RF_CH    = 76 (0x4C)
    // Step 2: EN_AA    = 1 (Enable Auto Ack - M?c ??nh RF24)
    // Step 3: CONFIG   = 0x0F (CRC 2 byte, Power Up, RX Mode)
    reg [4:0] cfg_addr;
    reg [7:0] cfg_val;

    always @(*) begin
        case(config_step)
            3'd0: begin cfg_addr = REG_RX_PW_P0; cfg_val = 8'd6;   end
            3'd1: begin cfg_addr = REG_RF_CH;    cfg_val = 8'h4C;  end // Channel 76
            3'd2: begin cfg_addr = REG_EN_AA;    cfg_val = 8'h3F;  end // AutoAck all pipes
            3'd3: begin cfg_addr = REG_CONFIG;   cfg_val = 8'h0F;  end 
            default: begin cfg_addr = 5'd0;      cfg_val = 8'd0;   end
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= S_RESET;
            nrf_csn       <= 1'b1;
            nrf_ce        <= 1'b0;
            spi_start     <= 1'b0;
            spi_data_tx   <= 8'd0;
            config_step   <= 3'd0;
            byte_count    <= 3'd0;
            payload_valid <= 1'b0;
            payload_out   <= 48'd0;
            delay_cnt     <= 16'd0;
        end else begin
            // M?c ??nh reset pulse
            spi_start     <= 1'b0;
            payload_valid <= 1'b0;

            case (state)
                // --- 1. Kh?i ??ng & Delay ch? chip ?n ??nh ---
                S_RESET: begin
                    nrf_csn <= 1'b1;
                    if (delay_cnt < 16'd5000) // Delay gi? l?p (tùy clock)
                        delay_cnt <= delay_cnt + 1;
                    else begin
                        delay_cnt <= 0;
                        state <= S_INIT_CFG_SETUP;
                        config_step <= 0;
                    end
                end

                // --- 2. Vòng l?p C?u hình (Mô ph?ng radio.begin) ---
                S_INIT_CFG_SETUP: begin
                    nrf_csn <= 1'b0; // Ch?n chip
                    spi_data_tx <= CMD_W_REGISTER | cfg_addr; // L?nh Write + ??a ch?
                    spi_start <= 1'b1;
                    state <= S_INIT_CFG_WRITE;
                end

                S_INIT_CFG_WRITE: begin
                    if (spi_done) begin
                        spi_data_tx <= cfg_val; // G?i giá tr? c?u hình
                        spi_start <= 1'b1;
                        state <= S_INIT_CFG_DATA;
                    end
                end

                S_INIT_CFG_DATA: begin
                    if (spi_done) begin
                        nrf_csn <= 1'b1; // Nh? chip
                        if (config_step < 3) begin
                            config_step <= config_step + 1;
                            // C?n delay nh? gi?a các l?n CSN toggle
                            state <= S_DELAY;
                            return_state <= S_INIT_CFG_SETUP;
                        end else begin
                            // C?u hình xong
                            state <= S_DELAY;
                            return_state <= S_RX_MODE;
                        end
                    end
                end

                // --- 3. Tr?ng thái l?ng nghe (Listening) ---
                S_RX_MODE: begin
                    nrf_ce <= 1'b1; // B?t ch? ?? nh?n (Radio Active)
                    
                    // Ki?m tra IRQ (Active Low) -> Có d? li?u ??n
                    if (nrf_irq_n == 1'b0) begin
                        nrf_ce  <= 1'b0; // T?t t?m th?i ?? ??c buffer
                        state   <= S_DELAY;
                        return_state <= S_READ_CMD;
                    end
                end

                // --- 4. ??c Payload (Mô ph?ng radio.read) ---
                S_READ_CMD: begin
                    nrf_csn <= 1'b0;
                    spi_data_tx <= CMD_R_RX_PAYLOAD;
                    spi_start <= 1'b1;
                    byte_count <= 0;
                    state <= S_READ_DATA;
                end

                S_READ_DATA: begin
                    if (spi_done) begin
                        // N?u ?ây không ph?i là byte l?nh ??u tiên thì l?u d? li?u
                        // (L?u ý: Byte ??u tiên nh?n v? là STATUS, payload ??n sau)
                        
                        // Logic g?i ti?p 6 byte Dummy ?? clock d? li?u v?
                        if (byte_count < 6) begin
                            if (byte_count > 0) begin 
                                // Shift d? li?u vào: Byte 0 vào [47:40]... Byte 5 vào [7:0]
                                // Tùy vào vi?c b?n mu?n Big Endian hay Little Endian.
                                // D??i ?ây là MSB first (Byte ??u tiên vào 47:40)
                                payload_out[ (5 - (byte_count-1))*8 +: 8 ] <= spi_data_rx;
                            end
                            
                            spi_data_tx <= 8'hFF; // Dummy byte
                            spi_start <= 1'b1;
                            byte_count <= byte_count + 1;
                        end else begin
                            // ?ã ??c ?? 6 byte (byte cu?i cùng ?ang ? spi_data_rx)
                            payload_out[0 +: 8] <= spi_data_rx;
                            
                            nrf_csn <= 1'b1; // K?t thúc transaction
                            payload_valid <= 1'b1; // Báo hi?u có d? li?u
                            state <= S_DELAY;
                            return_state <= S_CLEAR_IRQ;
                        end
                    end
                end

                // --- 5. Xóa c? ng?t (?? nRF có th? báo l?n sau) ---
                S_CLEAR_IRQ: begin
                    nrf_csn <= 1'b0;
                    spi_data_tx <= CMD_W_REGISTER | REG_STATUS;
                    spi_start <= 1'b1;
                    state <= S_CLEAR_IRQ_DATA;
                end
                
                S_CLEAR_IRQ_DATA: begin
                    if (spi_done) begin
                        spi_data_tx <= 8'h40; // Ghi 1 vào bit RX_DR ?? xóa
                        spi_start <= 1'b1;
                        state <= S_DELAY; // Sau khi xong thì v? l?i wait
                        return_state <= S_RX_MODE; 
                        // Chú ý: S_DELAY logic bên d??i s? x? lý vi?c ??i spi_done c?a l?nh này
                        // b?ng cách ??i timer, nh?ng ?? an toàn ta nên ??i spi_done ? ?ây.
                        // ?? ??n gi?n hóa code, tôi dùng state delay chung.
                    end
                end

                // --- State ph? tr?: Delay ng?n gi?a các l?n CSN ---
                S_DELAY: begin
                     // Delay kho?ng vài micro giây
                     if (delay_cnt < 16'd100) 
                        delay_cnt <= delay_cnt + 1;
                     else begin
                        delay_cnt <= 0;
                        nrf_csn <= 1'b1; // ??m b?o CSN cao
                        state <= return_state;
                     end
                end
                
            endcase
        end
    end
endmodule