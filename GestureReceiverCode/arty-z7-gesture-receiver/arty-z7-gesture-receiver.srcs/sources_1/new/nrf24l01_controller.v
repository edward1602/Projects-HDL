module nrf24l01_controller (
    input wire clk,
    input wire rst,
    
    // Output hi?n th? LED
    output reg [3:0] leds_out,
    
    // SPI Interface
    output reg spi_start,
    output reg [7:0] spi_data_in,
    input wire [7:0] spi_data_out,
    input wire spi_done,
    
    // NRF Pins
    output reg nrf_csn,
    output reg nrf_ce
);

    // --- ??NH NGH?A CÁC TR?NG THÁI (STATES) ---
    localparam S_INIT_WAIT      = 0;
    
    // Các b??c c?u hình (Main Sequence)
    localparam S_CFG_EN_AA      = 1;
    localparam S_CFG_CH         = 2;
    localparam S_CFG_SETUP      = 3;
    localparam S_CFG_PAYLOAD    = 4;
    localparam S_CFG_CONFIG     = 5;
    
    // Các tr?ng thái ho?t ??ng
    localparam S_RX_MODE        = 6;
    localparam S_POLL_STATUS    = 7;
    localparam S_READ_STATUS    = 8;
    localparam S_CHECK_FIFO     = 9;
    localparam S_READ_CMD       = 10;
    localparam S_READ_BYTES     = 11;
    localparam S_PROCESS_DATA   = 12;
    localparam S_CLEAR_IRQ      = 13;
    
    // --- TR?NG THÁI PH? (SUBROUTINES) ?? GHI REGISTER ---
    // Thay vì dùng hàm write_reg, ta dùng các state này ?? x? lý chung
    localparam S_WRITE_REG_CMD  = 20; // G?i l?nh (??a ch?)
    localparam S_WRITE_REG_VAL  = 21; // G?i giá tr?
    localparam S_WRITE_REG_DONE = 22; // K?t thúc (kéo CSN cao)

    reg [4:0] state;
    reg [4:0] return_state; // Bi?n nh? ?? bi?t quay v? ?âu sau khi ghi xong
    reg [19:0] delay_cnt;
    
    // Buffer d? li?u
    reg [2:0] byte_idx;
    reg [7:0] rx_buffer [0:5]; 
    reg [7:0] val_to_write; // Bi?n t?m l?u giá tr? c?n ghi vào Register
    
    // NRF Commands
    localparam CMD_W_REG = 8'h20;
    localparam CMD_R_REG = 8'h00;
    localparam CMD_R_RX  = 8'h61;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_INIT_WAIT;
            nrf_csn <= 1; nrf_ce <= 0;
            spi_start <= 0; delay_cnt <= 0;
            leds_out <= 0;
            byte_idx <= 0;
            return_state <= S_INIT_WAIT;
            val_to_write <= 0;
        end else begin
            case (state)
                // 1. Ch? kh?i ??ng ?n ??nh ?i?n áp
                S_INIT_WAIT: begin
                    delay_cnt <= delay_cnt + 1;
                    if (delay_cnt == 20'hFFFFF) state <= S_CFG_EN_AA;
                end
                
                // ==========================================
                // PH?N C?U HÌNH (Dùng c? ch? Jump & Return)
                // ==========================================
                
                // 2. T?t AutoAck: Ghi 0x00 vào REG 0x01
                S_CFG_EN_AA: begin
                    spi_data_in <= CMD_W_REG | 5'h01; // L?nh ghi vào Reg 0x01
                    val_to_write <= 8'h00;            // Giá tr? c?n ghi
                    return_state <= S_CFG_CH;         // Làm xong thì nh?y t?i b??c ti?p theo
                    state <= S_WRITE_REG_CMD;         // B?t ??u quy trình ghi
                end

                // 3. Set Kênh 2: Ghi 0x02 vào REG 0x05
                S_CFG_CH: begin
                    spi_data_in <= CMD_W_REG | 5'h05;
                    val_to_write <= 8'h02;
                    return_state <= S_CFG_SETUP;
                    state <= S_WRITE_REG_CMD;
                end

                // 4. Set 250KBPS: Ghi 0x26 vào REG 0x06
                S_CFG_SETUP: begin
                    spi_data_in <= CMD_W_REG | 5'h06;
                    val_to_write <= 8'h26;
                    return_state <= S_CFG_PAYLOAD;
                    state <= S_WRITE_REG_CMD;
                end

                // 5. Set Payload 6 Byte: Ghi 0x06 vào REG 0x11
                S_CFG_PAYLOAD: begin
                    spi_data_in <= CMD_W_REG | 5'h11;
                    val_to_write <= 8'h06;
                    return_state <= S_CFG_CONFIG;
                    state <= S_WRITE_REG_CMD;
                end

                // 6. Power Up + CRC: Ghi 0x0F vào REG 0x00
                S_CFG_CONFIG: begin
                    spi_data_in <= CMD_W_REG | 5'h00;
                    val_to_write <= 8'h0F;
                    return_state <= S_RX_MODE;
                    state <= S_WRITE_REG_CMD;
                end

                // ==========================================
                // SUBROUTINE: GHI REGISTER (Dùng chung)
                // ==========================================
                S_WRITE_REG_CMD: begin
                    nrf_csn <= 0;        // Kéo CSN xu?ng
                    spi_start <= 1;      // G?i byte Command (?ã set ? step tr??c)
                    if (spi_start) spi_start <= 0;
                    if (spi_done) state <= S_WRITE_REG_VAL;
                end

                S_WRITE_REG_VAL: begin
                    spi_data_in <= val_to_write; // G?i byte Giá tr?
                    spi_start <= 1;
                    if (spi_start) spi_start <= 0;
                    if (spi_done) state <= S_WRITE_REG_DONE;
                end
                
                S_WRITE_REG_DONE: begin
                    nrf_csn <= 1;        // Kéo CSN lên (K?t thúc transaction)
                    state <= return_state; // Quay v? b??c ti?p theo
                end

                // ==========================================
                // PH?N HO?T ??NG CHÍNH (Loop)
                // ==========================================
                
                // 7. B?t ch? ?? l?ng nghe
                S_RX_MODE: begin
                    nrf_ce <= 1; // Enable RX
                    delay_cnt <= delay_cnt + 1;
                    // Poll m?i ~2ms (gi? s? clock 125MHz)
                    if (delay_cnt[17]) begin 
                        delay_cnt <= 0;
                        state <= S_POLL_STATUS;
                    end
                end
                
                // 8. ??c tr?ng thái (Status Register)
                S_POLL_STATUS: begin
                    nrf_csn <= 0;
                    spi_data_in <= CMD_R_REG | 5'h07; // Read Status (0x07)
                    spi_start <= 1;
                    if (spi_start) spi_start <= 0;
                    if (spi_done) state <= S_READ_STATUS;
                end
                
                S_READ_STATUS: begin
                    spi_data_in <= 0; // Dummy byte
                    spi_start <= 1;
                    if (spi_start) spi_start <= 0;
                    if (spi_done) begin
                        nrf_csn <= 1;
                        state <= S_CHECK_FIFO;
                    end
                end
                
                // 9. Ki?m tra xem có d? li?u m?i không?
                S_CHECK_FIFO: begin
                    // spi_data_out lúc này ch?a giá tr? Status
                    if (spi_data_out[6]) begin // Bit 6 là RX_DR (Data Ready)
                        state <= S_READ_CMD;
                        byte_idx <= 0;
                        nrf_ce <= 0; // T?m t?t CE khi ?ang ??c (optional nh?ng an toàn)
                    end else begin
                        state <= S_RX_MODE; // Không có gì, quay l?i nghe
                    end
                end
                
                // 10. G?i l?nh ??c Payload
                S_READ_CMD: begin
                    nrf_csn <= 0;
                    spi_data_in <= CMD_R_RX;
                    spi_start <= 1;
                    if (spi_start) spi_start <= 0;
                    if (spi_done) state <= S_READ_BYTES;
                end
                
                // 11. ??c liên ti?p 6 byte
                S_READ_BYTES: begin
                    spi_data_in <= 0; // Dummy
                    spi_start <= 1;
                    if (spi_start) spi_start <= 0;
                    if (spi_done) begin
                        rx_buffer[byte_idx] <= spi_data_out;
                        if (byte_idx == 5) begin
                            nrf_csn <= 1;
                            state <= S_PROCESS_DATA;
                        end else begin
                            byte_idx <= byte_idx + 1;
                        end
                    end
                end
                
                // 12. X? lý d? li?u ra LED
                S_PROCESS_DATA: begin
                    leds_out[0] <= ~leds_out[0]; // Heartbeat: ??o tr?ng thái m?i khi nh?n gói tin
                    
                    // Arduino g?i int (2 byte). Byte cao ch?a thông tin signifikant h?n cho vi?c hi?n th? ??n gi?n
                    // [XL, XH, YL, YH, ZL, ZH]
                    // N?u giá tr? > 256 (t?c byte cao > 0) -> Sáng ?èn
                    leds_out[1] <= (rx_buffer[1] > 0); // X Axis
                    leds_out[2] <= (rx_buffer[3] > 0); // Y Axis
                    leds_out[3] <= (rx_buffer[5] > 0); // Z Axis
                    
                    // Chu?n b? xóa c? ng?t
                    spi_data_in <= CMD_W_REG | 5'h07;
                    val_to_write <= 8'h40; // Ghi 1 vào bit RX_DR ?? xóa
                    return_state <= S_RX_MODE;
                    state <= S_WRITE_REG_CMD; // Dùng l?i quy trình ghi register
                end
                
                // Các state S_CLEAR_IRQ ?ã ???c g?p vào logic chung ? trên
                
            endcase
        end
    end

endmodule