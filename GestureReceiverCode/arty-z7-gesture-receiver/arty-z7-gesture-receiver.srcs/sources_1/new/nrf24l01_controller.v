module nrf24l01_controller (
    input clk,
    input rst_n,
    
    // Giao di?n c?p cao
    input cmd_start,
    input [7:0] cmd_code,
    output reg cmd_done,
    
    // Giao di?n v?t lý nRF24L01
    output reg nrf_ce,
    output reg nrf_csn,
    input nrf_irq,
    output reg [7:0] status_reg_out, // Thanh ghi tr?ng thái ??c ???c
    
    // Giao di?n SPI
    output wire spi_sck,
    output wire spi_mosi,
    input spi_miso,
    
    // ??u ra D? li?u (Payload)
    output reg [5:0] rx_byte_count,  // S? byte ?ã nh?n ???c (cho FIFO)
    output reg [7:0] rx_byte_out,    // Byte d? li?u ?ang ???c ??c ra
    output reg rx_data_valid        // C? báo hi?u có d? li?u m?i trong rx_byte_out
);

    `include "nrf24l01_defines.v"
    
    reg spi_start;
    reg [7:0] spi_data_in;
    wire spi_transfer_done;
    wire [7:0] spi_data_out;
    
    reg [3:0] init_step_counter;
    
    reg [4:0] current_state, next_state; 
    reg [2:0] address_byte_counter; // Dùng cho ??a ch? 5 byte
    reg [2:0] payload_byte_counter; // B? ??m 6 byte (5 xu?ng 0)
    reg start_cmd_flag; // C? ?? chuy?n tr?ng thái sau khi l?nh hoàn t?t
    
    reg [7:0] current_addr_byte;
    
    spi_master spi_inst (
        .clk(clk),
        .rst_n(rst_n),
        .spi_clk_div(8'd50), // F_SCK ~ 1 MHz
        
        .start_transfer(spi_start),
        .transfer_done(spi_transfer_done),
        .data_in(spi_data_in),
        .data_out(spi_data_out),
    
        .spi_sck(spi_sck),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso)
    );
    
    // ----------------------------------------------------
    // Logic T? h?p: Xác ??nh tr?ng thái ti?p theo
    // ----------------------------------------------------
    always @* begin
        next_state = current_state;
        spi_start = 1'b0; // M?c ??nh không b?t ??u truy?n SPI
        nrf_csn = 1'b1;   // M?c ??nh CSN cao (không ho?t ??ng SPI)
    
        case (current_state)
            `STATE_IDLE: begin
                cmd_done = 1'b0;
                if (cmd_start) 
                    next_state = `STATE_INIT_START;
            end
            
            // ------------------------------------
            // B?t ??u Trình t? SPI (B??c 1)
            // ------------------------------------
            `STATE_INIT_START: begin
                // Kéo CSN xu?ng và chuy?n ??n b??c ghi thanh ghi ??u tiên
                nrf_csn = 1'b0; 
                next_state = `STATE_WRITE_CONFIG;
            end
            
            // ------------------------------------
            // Ghi CONFIG (B??c 2)
            // ------------------------------------
            `STATE_WRITE_CONFIG: begin
                nrf_csn = 1'b0;
                // Byte 1: L?nh Ghi Thanh ghi CONFIG
                if (!start_cmd_flag) begin
                    spi_data_in = `CMD_W_REGISTER | `REG_CONFIG;
                    spi_start = 1'b1;
                    start_cmd_flag = 1'b1;
                end
                
                // Byte 2: Giá tr? Thanh ghi CONFIG
                if (spi_transfer_done && start_cmd_flag) begin
                    // L?u tr?ng thái tr??c (tr?ng thái ??c ???c trong status_reg_out)
                    status_reg_out = spi_data_out; 
                    
                    spi_data_in = `VAL_CONFIG_TX; 
                    spi_start = 1'b1;
                    
                    // Ch? byte c?u hình ti?p theo hoàn thành
                    if (spi_transfer_done) begin
                        start_cmd_flag = 1'b0; // Reset c? cho l?nh ti?p theo
                        next_state = `STATE_WRITE_EN_AA;
                        nrf_csn = 1'b1; // K?t thúc chu k? SPI
                    end
                end
            end
            
            // ------------------------------------
            // Ghi EN_AA (B??c 3)
            // ------------------------------------
            `STATE_WRITE_EN_AA: begin
                nrf_csn = 1'b0;
                // Byte 1: L?nh Ghi Thanh ghi EN_AA
                if (!start_cmd_flag) begin
                    spi_data_in = `CMD_W_REGISTER | `REG_EN_AA;
                    spi_start = 1'b1;
                    start_cmd_flag = 1'b1;
                end
                
                // Byte 2: Giá tr? Thanh ghi EN_AA (0x00: T?t Auto-Ack)
                if (spi_transfer_done && start_cmd_flag) begin
                    spi_data_in = `VAL_EN_AA; 
                    spi_start = 1'b1;
                    
                    if (spi_transfer_done) begin
                        start_cmd_flag = 1'b0;
                        next_state = `STATE_WRITE_SETUP_AW;
                        nrf_csn = 1'b1;
                    end
                end
            end
            
            `STATE_WRITE_SETUP_AW: begin
                nrf_csn = 1'b0;
                // Byte 1: L?nh Ghi Thanh ghi SETUP_AW
                if (!start_cmd_flag) begin
                    spi_data_in = `CMD_W_REGISTER | `REG_SETUP_AW;
                    spi_start = 1'b1;
                    start_cmd_flag = 1'b1;
                end
                
                // Byte 2: Giá tr? Thanh ghi SETUP_AW (0x03)
                if (spi_transfer_done && start_cmd_flag) begin
                    status_reg_out = spi_data_out; // L?u Status c?
                    
                    spi_data_in = `VAL_SETUP_AW; 
                    spi_start = 1'b1;
                    
                    if (spi_transfer_done) begin
                        start_cmd_flag = 1'b0;
                        next_state = `STATE_WRITE_RF_SETUP; // Chuy?n sang b??c ti?p theo
                        nrf_csn = 1'b1; // K?t thúc chu k? SPI
                    end
                end
            end
            
            `STATE_WRITE_RF_SETUP: begin
                nrf_csn = 1'b0;
                // Byte 1: L?nh Ghi Thanh ghi RF_SETUP
                if (!start_cmd_flag) begin
                    spi_data_in = `CMD_W_REGISTER | `REG_RF_SETUP;
                    spi_start = 1'b1;
                    start_cmd_flag = 1'b1;
                end
                
                // Byte 2: Giá tr? Thanh ghi RF_SETUP (0x26)
                if (spi_transfer_done && start_cmd_flag) begin
                    status_reg_out = spi_data_out;
                    
                    spi_data_in = `VAL_RF_SETUP; 
                    spi_start = 1'b1;
                    
                    if (spi_transfer_done) begin
                        start_cmd_flag = 1'b0;
                        next_state = `STATE_WRITE_RX_PW; // Chuy?n sang b??c ti?p theo
                        nrf_csn = 1'b1;
                    end
                end
            end
            
            `STATE_WRITE_RX_PW: begin
                nrf_csn = 1'b0;
                // Byte 1: L?nh Ghi Thanh ghi RX_PW_P0
                if (!start_cmd_flag) begin
                    spi_data_in = `CMD_W_REGISTER | `REG_RX_PW_P0;
                    spi_start = 1'b1;
                    start_cmd_flag = 1'b1;
                end
                
                // Byte 2: Giá tr? Thanh ghi RX_PW_P0 (0x06)
                if (spi_transfer_done && start_cmd_flag) begin
                    status_reg_out = spi_data_out;
                    
                    spi_data_in = `VAL_RX_PW_P0; 
                    spi_start = 1'b1;
                    
                    if (spi_transfer_done) begin
                        start_cmd_flag = 1'b0;
                        // B??C QUAN TR?NG: Ghi ??a ch? 5 Byte
                        next_state = `STATE_WRITE_TX_ADDR_CMD; 
                        nrf_csn = 1'b1;
                    end
                end
            end
            
            `STATE_WRITE_TX_ADDR_CMD: begin
                nrf_csn = 1'b0;
                // Byte 1: L?nh Ghi Thanh ghi TX_ADDR
                if (!start_cmd_flag) begin
                    // ??t b? ??m byte ??a ch?: 4 (t? E7[4]) xu?ng 0 (E7[0])
                    address_byte_counter <= 3'd4; 
                    
                    spi_data_in = `CMD_W_REGISTER | `REG_TX_ADDR; 
                    spi_start = 1'b1;
                    start_cmd_flag = 1'b1;
                end
                
                // Ch? l?nh hoàn thành và chuy?n sang tr?ng thái g?i các byte ??a ch?
                if (spi_transfer_done && start_cmd_flag) begin
                    status_reg_out = spi_data_out;
                    start_cmd_flag = 1'b0;
                    // GI? CSN TH?P ?? g?i 5 byte ??a ch? ti?p theo
                    next_state = `STATE_WRITE_TX_ADDR_BYTE; 
                end
            end
            
            `STATE_WRITE_TX_ADDR_BYTE: begin
                nrf_csn = 1'b0; // Gi? CSN th?p trong su?t quá trình ghi 5 byte
                
                // L?y byte ??a ch? d?a trên b? ??m
                case (address_byte_counter)
                    3'd4: spi_data_in = `ADDR_BYTE_4; // Byte ??u tiên (MSB)
                    3'd3: spi_data_in = `ADDR_BYTE_3;
                    3'd2: spi_data_in = `ADDR_BYTE_2;
                    3'd1: spi_data_in = `ADDR_BYTE_1;
                    3'd0: spi_data_in = `ADDR_BYTE_0; // Byte cu?i cùng (LSB)
                    default: spi_data_in = 8'h00;
                endcase
                
                spi_start = 1'b1; // B?t ??u truy?n byte ??a ch? hi?n t?i
                
                if (spi_transfer_done) begin
                    status_reg_out = spi_data_out;
                    
                    if (address_byte_counter == 3'd0) begin
                        // ?ã g?i xong byte cu?i cùng (ADDR_BYTE_0)
                        next_state = `STATE_INIT_DONE; // Chuy?n sang k?t thúc
                        nrf_csn = 1'b1; // K?t thúc chu k? SPI ngay l?p t?c
                    end else begin
                        // Gi?m b? ??m và ti?p t?c g?i byte ti?p theo
                        address_byte_counter <= address_byte_counter - 1;
                        next_state = `STATE_WRITE_TX_ADDR_BYTE; // Quay l?i tr?ng thái này
                        nrf_csn = 1'b0; // Gi? CSN th?p
                    end
                end
            end
            
            `STATE_INIT_DONE: begin
                nrf_csn = 1'b1; // ??m b?o CSN cao
                nrf_ce = 1'b0;  // ??m b?o CE th?p (Standby-I)
                
                // Xóa c? tr?ng thái kh?i t?o/g?i l?nh
                start_cmd_flag = 1'b0;
                
                cmd_done = 1'b1; // Báo hi?u ?ã hoàn thành l?nh
                
                next_state = `STATE_SET_RX_MODE; // Quay l?i tr?ng thái ngh?
            end
            
            `STATE_SET_RX_MODE: begin
                nrf_csn = 1'b0;
                if (!start_cmd_flag) begin
                    spi_data_in = `CMD_W_REGISTER | `REG_CONFIG;
                    spi_start = 1'b1;
                    start_cmd_flag = 1'b1;
                end
                if (spi_transfer_done && start_cmd_flag) begin
                    spi_data_in = 8'h0F; // CONFIG: PWR_UP=1, PRIM_RX=1
                    spi_start = 1'b1;
                    if (spi_transfer_done) begin
                        start_cmd_flag = 1'b0;
                        nrf_csn = 1'b1;
                        nrf_ce = 1'b1;
                        next_state = `STATE_RX_WAIT; 
                    end
                end
            end
            
            `STATE_FLUSH_RX: begin
                nrf_csn = 1'b0;
                // Byte 1: L?nh FLUSH_RX (0xE2)
                if (!start_cmd_flag) begin
                    spi_data_in = `CMD_FLUSH_RX; 
                    spi_start = 1'b1;
                    start_cmd_flag = 1'b1;
                end
                
                // L?nh FLUSH ch? c?n 1 byte.
                if (spi_transfer_done && start_cmd_flag) begin
                    status_reg_out = spi_data_out; // Status ???c ??c trong khi g?i l?nh
                    start_cmd_flag = 1'b0;
                    nrf_csn = 1'b1;
                    
                    next_state = `STATE_RX_WAIT; // Chuy?n sang ch? ?? ch? d? li?u
                end
            end
            
            `STATE_RX_WAIT: begin
                if (nrf_irq == 1'b0) begin 
                    // Có ng?t: Kéo CE xu?ng ?? d?ng ho?t ??ng radio và ??c d? li?u
                    nrf_ce = 1'b0; 
                    next_state = `STATE_RX_READ_STATUS; 
                end else begin
                    next_state = `STATE_RX_WAIT;
                end
            end
            
            `STATE_RX_READ_STATUS: begin
                nrf_csn = 1'b0;
                spi_data_in = `CMD_R_REGISTER | `REG_STATUS; // L?nh ??c tr?ng thái
                spi_start = 1'b1;
                
                if (spi_transfer_done) begin
                    status_reg_out = spi_data_out; // L?u tr?ng thái
                    // Ki?m tra bit RX_DR (bit 6) c?a Status Register
                    if (spi_data_out[6] == 1'b1) begin
                        payload_byte_counter = 3'd5; // B?t ??u ??m ng??c 6 byte (5 ??n 0)
                        next_state = `STATE_RX_READ_PAYLOAD_CMD; // D? li?u có s?n
                    end else begin
                        next_state = `STATE_RX_CLEAR_IRQ; // Ng?t không ph?i do RX_DR
                    end
                    nrf_csn = 1'b1; // K?t thúc chu k? SPI
                end
            end
            
            `STATE_RX_READ_PAYLOAD_CMD: begin
                nrf_csn = 1'b0;
                spi_data_in = `CMD_R_RX_PAYLOAD; // L?nh ??c Payload (?ã thêm vào defines)
                spi_start = 1'b1;
                
                if (spi_transfer_done) begin
                    status_reg_out = spi_data_out; // Status ???c ??c l?i trong l?nh này
                    next_state = `STATE_RX_READ_PAYLOAD_BYTE; 
                end
            end
            
            `STATE_RX_READ_PAYLOAD_BYTE: begin
                nrf_csn = 1'b0;
                spi_data_in = 8'h00; // G?i 0x00 ?? Clock out d? li?u
                spi_start = 1'b1;
                
                if (spi_transfer_done) begin
                    rx_byte_out = spi_data_out; // D? li?u nh?n ???c
                    rx_byte_count = payload_byte_counter; // ??m byte
                    rx_data_valid = 1'b1; // Báo hi?u byte d? li?u h?p l?
                    
                    if (payload_byte_counter == 3'd0) begin
                        next_state = `STATE_RX_CLEAR_IRQ; // Hoàn thành ??c 6 byte
                        nrf_csn = 1'b1; // K?t thúc chu k? SPI
                    end else begin
                        // Ti?p t?c ??c byte ti?p theo
                        payload_byte_counter <= payload_byte_counter - 1; 
                        next_state = `STATE_RX_READ_PAYLOAD_BYTE;
                    end
                end
            end
            
            `STATE_RX_CLEAR_IRQ: begin
                nrf_csn = 1'b0;
                spi_data_in = `CMD_W_REGISTER | `REG_STATUS; // L?nh ghi Status
                spi_start = 1'b1;
                
                if (spi_transfer_done) begin
                    // Ghi l?i giá tr? Status v?i c? RX_DR (bit 6) ???c xóa
                    spi_data_in = 8'b01000000; // Ch? xóa RX_DR (bit 6) và TX_DS (bit 5) và MAX_RT (bit 4)
                    spi_start = 1'b1;
                    
                    if (spi_transfer_done) begin
                        nrf_csn = 1'b1;
                        next_state = `STATE_RX_WAIT; // Quay l?i ch? ?? ch?
                    end
                end
            end
            
            default: next_state = `STATE_IDLE;
        endcase
    end
    
    // Logic Tu?n t? (ch? c?p nh?t các thanh ghi tr?ng thái)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // --- Reset
            current_state <= `STATE_IDLE;
            nrf_csn <= 1'b1;
            nrf_ce <= 1'b0;
            cmd_done <= 1'b0;
            start_cmd_flag <= 1'b0;
            spi_start <= 1'b0; 
            spi_data_in <= 8'h00; 
            address_byte_counter <= 3'h0;
            payload_byte_counter <= 3'h0;
            rx_data_valid <= 1'b0;
        end else begin
            // --- C?p nh?t Tu?n t?
            current_state <= next_state;
            
            // C?p nh?t các reg không ???c c?p nh?t trong logic t? h?p
            if (current_state != next_state) begin
                 // Reset c? khi tr?ng thái thay ??i
                 start_cmd_flag <= 1'b0; 
                 spi_start <= 1'b0;
            end
            
            // C?p nh?t các reg d?a trên Logic T? h?p
            if (current_state == `STATE_WRITE_TX_ADDR_BYTE && spi_transfer_done && address_byte_counter != 3'd0) begin
                address_byte_counter <= address_byte_counter - 1;
            end
            
            if (current_state == `STATE_RX_READ_PAYLOAD_BYTE && spi_transfer_done && payload_byte_counter != 3'd0) begin
                payload_byte_counter <= payload_byte_counter - 1;
            end
            
        end
    end
    
endmodule