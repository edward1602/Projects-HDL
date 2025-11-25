// --- COMMANDS ---
`define CMD_R_REGISTER      8'b00000000 
`define CMD_W_REGISTER      8'b00100000 
`define CMD_R_RX_PAYLOAD    8'b01100001 // Thêm: ??c Payload
`define CMD_FLUSH_RX        8'b11100010 // Thêm: Xóa RX FIFO

// --- REGISTER ADDRESSES ---
`define REG_CONFIG          8'h00
`define REG_EN_AA           8'h01
`define REG_EN_RXADDR       8'h02
`define REG_SETUP_AW        8'h03
`define REG_SETUP_RETR      8'h04
`define REG_RF_CH           8'h05      // Thêm: Kênh t?n s?
`define REG_RF_SETUP        8'h06
`define REG_STATUS          8'h07
`define REG_TX_ADDR         8'h10
`define REG_RX_PW_P0        8'h11

// --- CONFIG VALUES ---
`define VAL_EN_AA           8'h00
`define VAL_SETUP_AW        8'h03
`define VAL_RF_CH           8'h02      // Channel 2
`define VAL_RF_SETUP        8'h26
`define VAL_RX_PW_P0        8'h06
`define VAL_CONFIG_TX       8'h0E     // TX Mode
`define VAL_CONFIG_RX       8'h0F     // RX Mode (S? dùng trong STATE_SET_RX_MODE)

// --- ADDRESS BYTES ---
`define ADDR_BYTE_0         8'hE7
`define ADDR_BYTE_1         8'hE7
`define ADDR_BYTE_2         8'hE7
`define ADDR_BYTE_3         8'hE7
`define ADDR_BYTE_4         8'hE7

// --- HIGH-LEVEL CONTROLLER STATES ---
`define STATE_IDLE              5'd00
// INIT SEQUENCE (01-10)
`define STATE_INIT_START        5'd01
`define STATE_WRITE_CONFIG      5'd02
`define STATE_WRITE_EN_AA       5'd03
`define STATE_WRITE_SETUP_AW    5'd04
`define STATE_WRITE_RF_SETUP    5'd05
`define STATE_WRITE_RX_PW       5'd06
`define STATE_WRITE_TX_ADDR_CMD 5'd07
`define STATE_WRITE_TX_ADDR_BYTE 5'd08
`define STATE_INIT_DONE         5'd09
`define STATE_SET_RX_MODE       5'd10
// RX SEQUENCE (11-16)
`define STATE_RX_WAIT           5'd11
`define STATE_FLUSH_RX          5'd12 // Thêm: Xóa FIFO tr??c khi ch?
`define STATE_RX_READ_STATUS    5'd13 // Thêm: ??c tr?ng thái ng?t
`define STATE_RX_READ_PAYLOAD_CMD 5'd14 // Thêm: G?i l?nh ??c payload
`define STATE_RX_READ_PAYLOAD_BYTE 5'd15 // Thêm: ??c t?ng byte
`define STATE_RX_CLEAR_IRQ      5'd16 // Thêm: Xóa c? ng?t