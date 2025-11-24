`timescale 1ns / 1ps

// Basic SPI Slave Model (MOCK NRF24L01)
module fake_nrf(
    input wire sck,
    input wire mosi,
    output reg miso,
    input wire csn,
    input wire ce,
    
    // Tín hi?u ?i?u khi?n cho Testbench
    input wire [7:0] p0_in, p1_in, p2_in, p3_in, p4_in, p5_in, // D? li?u mu?n gi? l?p
    input wire trigger_rx_interrupt // Kích ho?t c? báo có d? li?u
);

    // Các l?nh c?a NRF24L01
    localparam CMD_R_RX_PAYLOAD = 8'h61;
    localparam CMD_W_REGISTER   = 8'h20;
    localparam CMD_NOP          = 8'hFF;
    localparam REG_STATUS       = 8'h07;

    reg [7:0] shift_reg_tx;
    reg [7:0] shift_reg_rx;
    reg [2:0] bit_cnt;
    
    // Thanh ghi tr?ng thái gi? l?p (Bit 6 là RX_DR)
    reg [7:0] status_reg; 
    reg [7:0] payload_mem [0:5]; // B? nh? ??m cho 6 byte payload
    reg [3:0] byte_index;        // ??m s? byte ?ã g?i trong m?t transaction
    reg [7:0] last_cmd;
    
    initial begin
        miso = 0;
        status_reg = 8'h0E; // M?c ??nh: RX FIFO empty
        byte_index = 0;
    end

    // 1. Logic nh?n d? li?u vào buffer gi? l?p khi Testbench kích ho?t
    always @(posedge trigger_rx_interrupt) begin
        status_reg[6] <= 1; // Set bit RX_DR (Data Ready)
        status_reg[3:1] <= 3'b000; // RX_P_NO = 0
        
        // N?p d? li?u vào b? nh? gi?
        payload_mem[0] <= p0_in; payload_mem[1] <= p1_in;
        payload_mem[2] <= p2_in; payload_mem[3] <= p3_in;
        payload_mem[4] <= p4_in; payload_mem[5] <= p5_in;
        $display("[NRF_FAKE] Received Packet from Air (Simulated). RX_DR set to 1.");
    end

    // 2. Logic SPI Slave (Shift data)
    // Detect falling edge of CSN to reset transaction
    always @(negedge csn) begin
        bit_cnt <= 0;
        byte_index <= 0;
        shift_reg_tx <= status_reg; // M?c ??nh luôn g?i Status byte ??u tiên
        miso <= status_reg[7];      // Set MSB ngay l?p t?c
    end

    // Sample MOSI at rising edge, Shift MISO at falling edge (Mode 0 logic, but simplified)
    // L?u ý: Master c?a b?n ?ang ch?y Mode 0 (Sample Rising, Setup Falling)
    // Slave nên: Setup MISO on Falling (?? Master ??c ? Rising k? ti?p), Sample MOSI on Rising.
    
    always @(posedge sck) begin
        if (!csn) begin
            shift_reg_rx <= {shift_reg_rx[6:0], mosi};
            bit_cnt <= bit_cnt + 1;
        end
    end

    always @(negedge sck) begin
        if (!csn) begin
            // Shift out next bit
            if (bit_cnt == 0) begin
               // Byte boundary finished previously, logic handled below
            end else begin
               miso <= shift_reg_tx[7 - bit_cnt]; 
            end
            
            // X? lý khi nh?n ?? 1 byte (8 bits) t?i c?nh lên th? 8, x? lý t?i c?nh xu?ng
            if (bit_cnt == 0 && byte_index > 0) begin 
                 // Chu?n b? bit 7 cho byte ti?p theo
                 miso <= shift_reg_tx[7];
            end
        end
    end

    // X? lý Logic L?nh sau khi nh?n ?? 8 bit
    always @(posedge sck) begin
        if (!csn && bit_cnt == 3'b000) begin // V?a nh?n xong byte (bit_cnt wrap v? 0)
            
            // === Byte ??u tiên (Command) ===
            if (byte_index == 0) begin
                last_cmd <= shift_reg_rx;
                
                // N?u l?nh là ??c Payload, chu?n b? byte data ??u tiên cho l?n shift k?
                if (shift_reg_rx == CMD_R_RX_PAYLOAD) begin
                    shift_reg_tx <= payload_mem[0];
                end 
                else begin
                    shift_reg_tx <= 0; // Default status or 0
                end
            end 
            // === Các Byte ti?p theo (Data) ===
            else begin
                // X? lý l?nh xóa ng?t (Write Register Status)
                if ((last_cmd & 8'hE0) == CMD_W_REGISTER && (last_cmd & 8'h1F) == REG_STATUS) begin
                    if (shift_reg_rx[6] == 1) begin
                        status_reg[6] <= 0; // Xóa c? RX_DR
                        $display("[NRF_FAKE] RX_DR Cleared by Master.");
                    end
                end
                
                // Chu?n b? d? li?u cho byte ti?p theo n?u ?ang ??c Payload
                if (last_cmd == CMD_R_RX_PAYLOAD) begin
                    if (byte_index < 6)
                        shift_reg_tx <= payload_mem[byte_index];
                    else
                        shift_reg_tx <= 0;
                end
            end
            
            byte_index <= byte_index + 1;
        end
    end

endmodule