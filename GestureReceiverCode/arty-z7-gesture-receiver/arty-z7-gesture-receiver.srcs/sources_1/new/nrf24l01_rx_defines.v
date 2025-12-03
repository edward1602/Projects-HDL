//==============================================================================
// NRF24L01 SIMPLIFIED RX-ONLY DEFINITIONS FOR ARTY Z7
//==============================================================================
// This file contains simplified definitions for RX-only operation on Arty Z7.
// The configuration is optimized for simple gesture data reception without
// any transmission capability.
//
// RX-ONLY Configuration for Arty Z7:
// - Operating frequency: 2.476 GHz (Channel 76)
// - Data rate: 250 Kbps (matches Arduino transmitter) (best compatibility)
// - Address width: 5 bytes
// - Payload width: 6 bytes (for 3-axis gesture data: X, Y, Z) 
// - Auto-acknowledgment: Disabled (simplex communication)
// - Mode: RX only - no transmission capability needed
//==============================================================================

// --- NRF24L01 SPI COMMANDS (Essential for RX) ---
`define CMD_R_REGISTER      8'b00000000 // Read command and status registers
`define CMD_W_REGISTER      8'b00100000 // Write command and status registers  
`define CMD_R_RX_PAYLOAD    8'b01100001 // Read RX payload (main command for data reception)
`define CMD_FLUSH_RX        8'b11100010 // Flush RX FIFO (clear old data)

// --- NRF24L01 REGISTER ADDRESSES (RX Essential) ---
`define REG_CONFIG          8'h00      // Configuration register
`define REG_EN_RXADDR       8'h02      // Enable RX addresses (must enable pipe 0)
`define REG_SETUP_AW        8'h03      // Setup of address widths
`define REG_RF_CH           8'h05      // RF channel frequency
`define REG_RF_SETUP        8'h06      // RF setup register  
`define REG_STATUS          8'h07      // Status register
`define REG_RX_ADDR_P0      8'h0A      // Receive address data pipe 0
`define REG_RX_PW_P0        8'h11      // RX payload width for data pipe 0

// --- SIMPLIFIED RX-ONLY CONFIGURATION VALUES ---
`define VAL_CONFIG_RX_ONLY  8'h0F      // PWR_UP=1, PRIM_RX=1, EN_CRC=1, CRCO=1
`define VAL_EN_RXADDR       8'h01      // Enable data pipe 0 only
`define VAL_SETUP_AW        8'h03      // 5 bytes address width
`define VAL_RF_CH           8'h4C      // RF channel 76 (2.476 GHz)
`define VAL_RF_SETUP        8'h26      // 250Kbps, -6dBm (matches Arduino transmitter)
`define VAL_RX_PW_P0        8'h06      // 6 bytes payload width

// --- SIMPLE 5-BYTE RX ADDRESS ---
// Address for receiving gesture data: 0xE7E7E7E7E7
`define ADDR_BYTE_0         8'hE7      // Address byte 0 (LSB)
`define ADDR_BYTE_1         8'hE7      // Address byte 1
`define ADDR_BYTE_2         8'hE7      // Address byte 2 
`define ADDR_BYTE_3         8'hE7      // Address byte 3
`define ADDR_BYTE_4         8'hE7      // Address byte 4 (MSB)

// --- SIMPLIFIED RX-ONLY STATE MACHINE ---
`define STATE_IDLE              5'd00  // Idle state

// SIMPLE RX INITIALIZATION (States 01-09)
`define STATE_INIT_START        5'd01  // Start with power-up delay
`define STATE_WRITE_CONFIG      5'd02  // Write CONFIG register (RX mode)
`define STATE_WRITE_EN_RXADDR   5'd03  // Enable RX data pipe 0
`define STATE_WRITE_SETUP_AW    5'd04  // Set 5-byte address width
`define STATE_WRITE_RF_CH       5'd05  // Set RF channel
`define STATE_WRITE_RF_SETUP    5'd06  // Configure RF settings
`define STATE_WRITE_RX_PW       5'd07  // Set RX payload width
`define STATE_WRITE_RX_ADDR_CMD 5'd08  // Send RX address command
`define STATE_WRITE_RX_ADDR_BYTE 5'd09 // Write RX address bytes
`define STATE_RX_READY          5'd10  // RX mode active - ready to receive

// SIMPLE RX OPERATION (States 11-14)
`define STATE_RX_STATUS_CMD     5'd11  // Poll: send STATUS read command
`define STATE_RX_STATUS_READ    5'd12  // Poll: read STATUS byte
`define STATE_RX_READ_PAYLOAD_CMD 5'd13 // Send read payload command
`define STATE_RX_READ_PAYLOAD_BYTE 5'd14 // Read payload bytes
`define STATE_RX_CLEAR_IRQ      5'd15  // Clear RX_DR interrupt