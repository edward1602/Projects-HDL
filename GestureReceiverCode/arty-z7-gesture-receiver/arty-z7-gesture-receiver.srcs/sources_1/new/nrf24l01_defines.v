//==============================================================================
// NRF24L01 WIRELESS MODULE DEFINITIONS
//==============================================================================
// This file contains all register addresses, command definitions, configuration
// values, and state machine definitions for controlling the NRF24L01 2.4GHz
// wireless transceiver module via SPI interface.
//
// RX-ONLY Configuration for Arty Z7:
// - Operating frequency: 2.402 GHz (Channel 2)
// - Data rate: 1 Mbps (best compatibility)
// - Address width: 5 bytes
// - Payload width: 6 bytes (for 3-axis gesture data: X, Y, Z) 
// - Auto-acknowledgment: Disabled (simplex communication)
// - Mode: RX only - no transmission capability needed
//==============================================================================

// --- NRF24L01 SPI COMMANDS ---
`define CMD_R_REGISTER      8'b00000000 // Read command and status registers
`define CMD_W_REGISTER      8'b00100000 // Write command and status registers  
`define CMD_R_RX_PAYLOAD    8'b01100001 // Read RX payload: 1-32 bytes. A read operation always starts at byte 0
`define CMD_FLUSH_RX        8'b11100010 // Flush RX FIFO, used in RX mode

// --- NRF24L01 REGISTER ADDRESSES ---
`define REG_CONFIG          8'h00      // Configuration register
`define REG_EN_AA           8'h01      // Enable Auto Acknowledgment function
`define REG_EN_RXADDR       8'h02      // Enabled RX addresses
`define REG_SETUP_AW        8'h03      // Setup of address widths (common for all data pipes)
`define REG_SETUP_RETR      8'h04      // Setup of automatic retransmission
`define REG_RF_CH           8'h05      // RF channel frequency
`define REG_RF_SETUP        8'h06      // RF setup register
`define REG_STATUS          8'h07      // Status register (In parallel to the SPI command word)
`define REG_RX_ADDR_P0      8'h0A      // Receive address data pipe 0 (must match TX_ADDR for auto-ack)
`define REG_TX_ADDR         8'h10      // Transmit address (used for a PTX device only)
`define REG_RX_PW_P0        8'h11      // Number of bytes in RX payload in data pipe 0

// --- CONFIGURATION VALUES ---
`define VAL_EN_AA           8'h00      // Disable auto acknowledgment on all data pipes
`define VAL_EN_RXADDR       8'h01      // Enable data pipe 0 (bit 0 = 1)
`define VAL_SETUP_AW        8'h03      // 5 bytes address width (11 = 5 bytes)
`define VAL_RF_CH           8'h02      // RF channel 2 (2.402 GHz)
`define VAL_RF_SETUP        8'h07      // RF_DR_LOW=0, RF_DR_HIGH=0, RF_PWR=11 (1Mbps, 0dBm - best range)
`define VAL_RX_PW_P0        8'h06      // 6 bytes payload width for data pipe 0
`define VAL_CONFIG_RX_ONLY  8'h0F      // PWR_UP=1, PRIM_RX=1, EN_CRC=1, CRCO=1 (RX only mode)
`define VAL_CONFIG_POWERDOWN 8'h00     // PWR_UP=0 (Power down for initial config)

// --- 5-BYTE ADDRESS CONFIGURATION ---
// Default address: 0xE7E7E7E7E7 (LSB first transmission)
`define ADDR_BYTE_0         8'hE7      // Address byte 0 (LSB)
`define ADDR_BYTE_1         8'hE7      // Address byte 1
`define ADDR_BYTE_2         8'hE7      // Address byte 2 
`define ADDR_BYTE_3         8'hE7      // Address byte 3
`define ADDR_BYTE_4         8'hE7      // Address byte 4 (MSB)

// --- NRF24L01 CONTROLLER STATE MACHINE ---
`define STATE_IDLE              5'd00  // Idle state - waiting for commands

// SIMPLIFIED RX-ONLY INITIALIZATION (States 01-08)
`define STATE_INIT_START        5'd01  // Start initialization sequence  
`define STATE_POWER_DOWN_CONFIG 5'd02  // Initial power-down config for setup
`define STATE_WRITE_EN_AA       5'd03  // Write EN_AA register (disable auto-ack)
`define STATE_WRITE_EN_RXADDR   5'd04  // Write EN_RXADDR register (enable data pipe 0)
`define STATE_WRITE_SETUP_AW    5'd05  // Write SETUP_AW register (5-byte address)
`define STATE_WRITE_RX_PW       5'd07  // Write RX_PW_P0 register (6-byte payload)
`define STATE_WRITE_TX_ADDR_CMD 5'd08  // Send W_REGISTER + TX_ADDR command
`define STATE_WRITE_TX_ADDR_BYTE 5'd09 // Write TX address bytes (5 bytes)
`define STATE_WRITE_RX_ADDR_CMD 5'd10  // Send W_REGISTER + RX_ADDR_P0 command
`define STATE_WRITE_RX_ADDR_BYTE 5'd11 // Write RX address bytes (5 bytes)
`define STATE_INIT_DONE         5'd12  // Initialization complete
`define STATE_SET_RX_MODE       5'd13  // Switch to RX mode (update CONFIG register)

// SIMPLIFIED RX OPERATION (States 11-15) 
`define STATE_RX_WAIT           5'd11  // Wait for RX_DR interrupt (data ready)
`define STATE_RX_READ_PAYLOAD_CMD 5'd12 // Send R_RX_PAYLOAD command
`define STATE_RX_READ_PAYLOAD_BYTE 5'd13 // Read payload bytes (6 bytes total)
`define STATE_RX_CLEAR_IRQ      5'd14  // Clear RX_DR interrupt flag
`define STATE_RX_READY_AGAIN    5'd15  // Return to ready state for next packet