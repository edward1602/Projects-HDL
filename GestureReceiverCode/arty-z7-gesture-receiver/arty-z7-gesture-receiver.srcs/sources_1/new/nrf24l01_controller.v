module nrf24l01_controller (
    input wire clk,
    input wire rst,
    
    // Output
    output reg [3:0] leds_out,
    output reg [15:0] x_out,
    output reg [15:0] y_out,
    output reg [15:0] z_out,
    
    // SPI Interface
    output reg spi_start,
    output reg [7:0] spi_data_in,
    input wire [7:0] spi_data_out,
    input wire spi_done,
    
    // NRF Pins
    output reg nrf_csn,
    output reg nrf_ce
);

    // --- CÁC TR?NG THÁI ---
    localparam S_INIT_WAIT = 0, S_CFG_EN_AA = 1, S_CFG_CH = 2, S_CFG_SETUP = 3;
    localparam S_CFG_PAYLOAD = 4, S_CFG_CONFIG = 5, S_RX_MODE = 6, S_POLL_STATUS = 7;
    localparam S_READ_STATUS = 8, S_CHECK_FIFO = 9, S_READ_CMD = 10;
    
    // --- S?A ??I: Tách S_READ_BYTES thành 2 tr?ng thái ---
    localparam S_READ_REQ  = 11; // G?i yêu c?u ??c
    localparam S_READ_WAIT = 12; // Ch? d? li?u v?
    
    localparam S_PROCESS_DATA = 13;
    
    // Subroutines ghi Register
    localparam S_WRITE_REG_CMD = 20, S_WRITE_REG_VAL = 21, S_WRITE_REG_DONE = 22;

    reg [4:0] state;
    reg [4:0] return_state;
    reg [19:0] delay_cnt;
    reg [2:0] byte_idx;
    
    // Buffer
    reg [7:0] rx_buffer [0:5]; 
    reg [7:0] val_to_write; 
    
    localparam CMD_W_REG = 8'h20;
    localparam CMD_R_REG = 8'h00;
    localparam CMD_R_RX  = 8'h61;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_INIT_WAIT;
            nrf_csn <= 1; nrf_ce <= 0;
            spi_start <= 0; delay_cnt <= 0;
            leds_out <= 4'b0000;
            return_state <= S_INIT_WAIT;
        end else begin
            case (state)
                S_INIT_WAIT: begin
                    delay_cnt <= delay_cnt + 1;
//                    if (delay_cnt == 20'hFFFFF) state <= S_CFG_EN_AA;
                    if (delay_cnt == 20'h000FF) state <= S_CFG_EN_AA;
                end
                
                // --- C?U HÌNH (CONFIG) ---
                S_CFG_EN_AA: begin 
                   spi_data_in <= CMD_W_REG | 5'h01; val_to_write <= 8'h00; // T?t AutoAck
                   return_state <= S_CFG_CH; state <= S_WRITE_REG_CMD;
                end
                S_CFG_CH: begin 
                   spi_data_in <= CMD_W_REG | 5'h05; val_to_write <= 8'h02; // Kênh 2
                   return_state <= S_CFG_SETUP; state <= S_WRITE_REG_CMD;
                end
                S_CFG_SETUP: begin 
                   spi_data_in <= CMD_W_REG | 5'h06; val_to_write <= 8'h26; // 250 KBPS
                   return_state <= S_CFG_PAYLOAD; state <= S_WRITE_REG_CMD;
                end
                S_CFG_PAYLOAD: begin 
                   spi_data_in <= CMD_W_REG | 5'h11; val_to_write <= 8'h06; // 6 BYTES
                   return_state <= S_CFG_CONFIG; state <= S_WRITE_REG_CMD;
                end
                S_CFG_CONFIG: begin 
                   spi_data_in <= CMD_W_REG | 5'h00; val_to_write <= 8'h0F; // Power UP + CRC
                   return_state <= S_RX_MODE; state <= S_WRITE_REG_CMD;
                end

                // --- RX LOOP ---
                S_RX_MODE: begin
                    nrf_ce <= 1; 
                    delay_cnt <= delay_cnt + 1;
                    // Poll nhanh h?n m?t chút ?? th?y ?èn nháy m??t
//                    if (delay_cnt[16]) begin delay_cnt <= 0; state <= S_POLL_STATUS; end
                    if (delay_cnt[3]) begin delay_cnt <= 0; state <= S_POLL_STATUS; end
                end
                
                S_POLL_STATUS: begin
                    nrf_csn <= 0; spi_data_in <= CMD_R_REG | 5'h07; spi_start <= 1;
                    if (spi_start) spi_start <= 0; if (spi_done) state <= S_READ_STATUS;
                end
                
                S_READ_STATUS: begin
                    spi_data_in <= 0; spi_start <= 1;
                    if (spi_start) spi_start <= 0; 
                    if (spi_done) begin nrf_csn <= 1; state <= S_CHECK_FIFO; end
                end
                
                S_CHECK_FIFO: begin
                    // L?c nhi?u c? b?n: N?u ??c ra 0xFF ho?c 0x00 toàn b? thì kh? n?ng cao là l?i dây
                    // Nh?ng ? ?ây ta c? ??c, vi?c l?c ?? ? b??c x? lý
                    if (spi_data_out[6]) begin 
                        state <= S_READ_CMD; byte_idx <= 0; 
                    end else begin
                        state <= S_RX_MODE;
                    end
                end
                
                S_READ_CMD: begin
                    nrf_csn <= 0; spi_data_in <= CMD_R_RX; spi_start <= 1;
                    if (spi_start) spi_start <= 0; if (spi_done) state <= S_READ_REQ;
                end
                
                // B??c 1: Kích ho?t SPI Start (Ch? 1 xung)
                S_READ_REQ: begin
                    spi_data_in <= 0; // Dummy byte
                    spi_start <= 1;   // Pulse start
                    state <= S_READ_WAIT; // Chuy?n ngay sang ch?
                end
                
                // B??c 2: Ch? SPI Done và l?u d? li?u
                S_READ_WAIT: begin
                    spi_start <= 0; // ??m b?o start ?ã t?t
                    
                    if (spi_done) begin
                        // L?u d? li?u vào buffer
                        rx_buffer[byte_idx] <= spi_data_out;
                        
                        // Ki?m tra ?ã ?? 6 byte ch?a (index 0 ??n 5)
                        if (byte_idx == 5) begin
                            nrf_csn <= 1; // ??c xong -> Kéo CSN lên
                            state <= S_PROCESS_DATA;
                        end else begin
                            byte_idx <= byte_idx + 1; // T?ng index
                            state <= S_READ_REQ;      // Quay l?i b??c 1 ?? ??c byte ti?p theo
                        end
                    end
                end

                // --- X? LÝ D? LI?U ---
                S_PROCESS_DATA: begin
                    // 1. LED 0: Heartbeat (Nh?p tim)
                    // M?i l?n nh?n ???c gói tin thành công -> ??o tr?ng thái
                    leds_out[0] <= ~leds_out[0]; 

                    // 2. LED 1, 2, 3: Hi?n th? giá tr? Tr?c X (Byte cao)
                    // rx_buffer[1] là X_High.
                    // N?u Joystick ? gi?a: X ~ 512 -> High Byte = 2 (Binary: 0000 0010) -> LED 2 sáng
                    // N?u Joystick Max: X ~ 1023 -> High Byte = 3 (Binary: 0000 0011) -> LED 2, LED 1 sáng
                    // N?u Joystick Min: X ~ 0 -> High Byte = 0 (Binary: 0000 0000) -> T?t h?t
                    
                    // Gán tr?c ti?p 3 bit cu?i c?a Byte cao vào LED
//                    leds_out[3:1] <= rx_buffer[0][7:5];
                    leds_out[3:1] <= rx_buffer[0][2:0];
                    
                    x_out <= {rx_buffer[1], rx_buffer[0]};
                    y_out <= {rx_buffer[3], rx_buffer[2]};
                    z_out <= {rx_buffer[5], rx_buffer[4]};
                    $display(rx_buffer);

                    // Xóa c? ng?t
                    spi_data_in <= CMD_W_REG | 5'h07; val_to_write <= 8'h40;
                    return_state <= S_RX_MODE; state <= S_WRITE_REG_CMD;
                end
                
                // --- SUBROUTINES ---
                S_WRITE_REG_CMD: begin
                    nrf_csn <= 0; spi_start <= 1; if (spi_start) spi_start <= 0; if (spi_done) state <= S_WRITE_REG_VAL;
                end
                S_WRITE_REG_VAL: begin
                    spi_data_in <= val_to_write; spi_start <= 1; if (spi_start) spi_start <= 0; if (spi_done) state <= S_WRITE_REG_DONE;
                end
                S_WRITE_REG_DONE: begin nrf_csn <= 1; state <= return_state; end

            endcase
        end
    end

endmodule