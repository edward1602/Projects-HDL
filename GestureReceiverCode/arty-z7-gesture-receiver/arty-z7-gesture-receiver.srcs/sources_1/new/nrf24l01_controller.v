module nrf24l01_controller (
    input clk,
    input rst_n,
    
    // Cmd interface
    input cmd_start,
    input [7:0] cmd_code,
    output reg cmd_done,
    
    // Physical interface to NRF24L01
    output reg nrf_ce,
    output reg nrf_csn,
    input nrf_irq,
    output reg [7:0] status_reg_out, // Status reg read out
    
    // SPI interface
    output wire spi_sck,
    output wire spi_mosi,
    input spi_miso,
    
    // Data output (Payload)
    output reg [5:0] rx_byte_count,  // Number of bytes received (for FIFO)
    output reg [7:0] rx_byte_out,    // Data byte currently beging read out
    output reg rx_data_valid        // Signal indicating new data available
);

    `include "nrf24l01_defines.v"
    
    reg spi_start;
    reg [7:0] spi_data_in;
    wire spi_transfer_done;
    wire [7:0] spi_data_out;
    
    reg [3:0] init_step_counter;
    reg [23:0] power_up_delay_counter; // 100ms delay counter at 100MHz
    
    reg [4:0] current_state, next_state; 
    reg [2:0] address_byte_counter; // Used for 5-byte addr
    reg [2:0] payload_byte_counter; // Counter for 6 bytes (from 5 down to 0)
    reg start_cmd_flag; // Flag to transition state after command completes
    reg spi_cmd_phase; // 0: command phase, 1: data phase
    
    reg [7:0] current_addr_byte;
    
    // Timing constants based on nRF24L01 datasheet
    parameter POWER_UP_DELAY = 24'd10_000_000; // 100ms at 100MHz (Section 6.1.1)
    parameter CSN_DELAY = 8'd100;               // 1μs CSN pulse width
    parameter CE_DELAY = 16'd1300;              // 13μs CE setup time
    parameter STANDBY_DELAY = 16'd15000;        // 150μs mode transition
    
    spi_master spi_inst (
        .clk(clk),
        .rst_n(rst_n),
        .spi_clk_div(8'd50), // SPI clock ~ 1 MHz
        
        .start_transfer(spi_start),
        .transfer_done(spi_transfer_done),
        .data_in(spi_data_in),
        .data_out(spi_data_out),
    
        .spi_sck(spi_sck),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso)
    );
    
    // ------------------------------------
    // Combinational logic: determine next state
    // ------------------------------------
    always @* begin
        next_state = current_state;
        spi_start = 1'b0; // Default: do not start SPI transfer
        nrf_csn = 1'b1;   // Default: CSN high (SPI inactive)
    
        case (current_state)
            // ------------------------------------
            // STATE_IDLE: wait for an external command (cmd_start) to begin initialization
            // ------------------------------------
            `STATE_IDLE: begin
                cmd_done = 1'b0;
                if (cmd_start) 
                    next_state = `STATE_INIT_START;
            end
            
            // ------------------------------------
            // STATE_INIT_START: Begin the NRF24L01 config sequence with power-up delay
            // ------------------------------------
            `STATE_INIT_START: begin
                nrf_csn = 1'b1; // Keep CSN high during power-up delay
                nrf_ce = 1'b0;  // Keep CE low
                
                if (power_up_delay_counter >= POWER_UP_DELAY) begin
                    next_state = `STATE_WRITE_CONFIG;
                end else begin
                    next_state = `STATE_INIT_START; // Stay in this state
                end
            end
            
            // ------------------------------------
            // STATE_WRITE_CONFIG: Write the CONFIG reg
            // Phase 0: Send command, Phase 1: Send data
            // ------------------------------------
            `STATE_WRITE_CONFIG: begin
                nrf_csn = 1'b0;
                
                if (!spi_cmd_phase) begin
                    // Phase 0: Send W_REGISTER + CONFIG command
                    spi_data_in = `CMD_W_REGISTER | `REG_CONFIG;
                    spi_start = 1'b1;
                    
                    if (spi_transfer_done) begin
                        status_reg_out = spi_data_out; // Save status
                        spi_cmd_phase = 1'b1; // Move to data phase
                    end
                end else begin
                    // Phase 1: Send CONFIG register value
                    spi_data_in = `VAL_CONFIG_TX;
                    spi_start = 1'b1;
                    
                    if (spi_transfer_done) begin
                        spi_cmd_phase = 1'b0; // Reset phase
                        next_state = `STATE_WRITE_EN_AA;
                        nrf_csn = 1'b1;
                    end
                end
            end
            
            // ------------------------------------
            // STATE_WRITE_EN_AA: Write the EN_AA reg (Disable Auto-Ack)
            // Phase 0: Command, Phase 1: Data
            // ------------------------------------
            `STATE_WRITE_EN_AA: begin
                nrf_csn = 1'b0;
                
                if (!spi_cmd_phase) begin
                    spi_data_in = `CMD_W_REGISTER | `REG_EN_AA;
                    spi_start = 1'b1;
                    
                    if (spi_transfer_done) begin
                        spi_cmd_phase = 1'b1;
                    end
                end else begin
                    spi_data_in = `VAL_EN_AA;
                    spi_start = 1'b1;
                    
                    if (spi_transfer_done) begin
                        spi_cmd_phase = 1'b0;
                        next_state = `STATE_WRITE_EN_RXADDR; // Add missing EN_RXADDR
                        nrf_csn = 1'b1;
                    end
                end
            end
            
            // ------------------------------------
            // STATE_WRITE_EN_RXADDR: Enable RX address for data pipe 0
            // CRITICAL: Must enable data pipe 0 for RX operation
            // ------------------------------------  
            `STATE_WRITE_EN_RXADDR: begin
                nrf_csn = 1'b0;
                
                if (!spi_cmd_phase) begin
                    spi_data_in = `CMD_W_REGISTER | `REG_EN_RXADDR;
                    spi_start = 1'b1;
                    
                    if (spi_transfer_done) begin
                        spi_cmd_phase = 1'b1;
                    end
                end else begin
                    spi_data_in = `VAL_EN_RXADDR; // Enable pipe 0
                    spi_start = 1'b1;
                    
                    if (spi_transfer_done) begin
                        spi_cmd_phase = 1'b0;
                        next_state = `STATE_WRITE_SETUP_AW;
                        nrf_csn = 1'b1;
                    end
                end
            end
                nrf_csn = 1'b0;
                // Byte 1: Write EN_AA register command
                if (!start_cmd_flag) begin
                    spi_data_in = `CMD_W_REGISTER | `REG_EN_AA;
                    spi_start = 1'b1;
                    start_cmd_flag = 1'b1;
                end
                
                // Byte 2: EN_AA register value (0x00: Disable Auto-Ack)
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
            
            // ------------------------------------
            // STATE_WRITE_SETUP_AW: Write SETUP_AW register to configure 5-byte address width
            // Byte 1: command
            // Byte 2: value
            // ------------------------------------
            `STATE_WRITE_SETUP_AW: begin
                nrf_csn = 1'b0;
                // Byte 1: Write SETUP_AW register command
                if (!start_cmd_flag) begin
                    spi_data_in = `CMD_W_REGISTER | `REG_SETUP_AW;
                    spi_start = 1'b1;
                    start_cmd_flag = 1'b1;
                end
                
                // Byte 2: RF_SETUP register value (0x26)
                if (spi_transfer_done && start_cmd_flag) begin
                    status_reg_out = spi_data_out;
                    
                    spi_data_in = `VAL_SETUP_AW; 
                    spi_start = 1'b1;
                    
                    if (spi_transfer_done) begin
                        start_cmd_flag = 1'b0;
                        next_state = `STATE_WRITE_RF_SETUP;
                        nrf_csn = 1'b1;
                    end
                end
            end
            
            // ------------------------------------
            // STATE_WRITE_RF_SETUP: Write RF_SETUP register to config data rate and transmit power
            // Byte 1: command
            // Byte 2: value
            // ------------------------------------
            `STATE_WRITE_RF_SETUP: begin
                nrf_csn = 1'b0;
                // Byte 1: Write RF_SETUP register command
                if (!start_cmd_flag) begin
                    spi_data_in = `CMD_W_REGISTER | `REG_RF_SETUP;
                    spi_start = 1'b1;
                    start_cmd_flag = 1'b1;
                end
                
                // Byte 2: RF_SETUP register value (0x26)
                if (spi_transfer_done && start_cmd_flag) begin
                    status_reg_out = spi_data_out;
                    
                    spi_data_in = `VAL_RF_SETUP; 
                    spi_start = 1'b1;
                    
                    if (spi_transfer_done) begin
                        start_cmd_flag = 1'b0;
                        next_state = `STATE_WRITE_RX_PW;
                        nrf_csn = 1'b1;
                    end
                end
            end
            
            // ------------------------------------
            // STATE_WRITE_RX_PW: Write RF_SETUP register to config data rate and transmit power
            // Byte 1: command
            // Byte 2: value
            // ------------------------------------
            `STATE_WRITE_RX_PW: begin
                nrf_csn = 1'b0;
                // Byte 1: Write RX_PW_P0 register command
                if (!start_cmd_flag) begin
                    spi_data_in = `CMD_W_REGISTER | `REG_RX_PW_P0;
                    spi_start = 1'b1;
                    start_cmd_flag = 1'b1;
                end
                
                // Byte 2: RX_PW_P0 register value (0x06)
                if (spi_transfer_done && start_cmd_flag) begin
                    status_reg_out = spi_data_out;
                    
                    spi_data_in = `VAL_RX_PW_P0; 
                    spi_start = 1'b1;
                    
                    if (spi_transfer_done) begin
                        start_cmd_flag = 1'b0;
                        // IMPORTANT STEP NEXT: Write 5-byte address
                        next_state = `STATE_WRITE_TX_ADDR_CMD; 
                        nrf_csn = 1'b1;
                    end
                end
            end
            
            // ------------------------------------
            // STATE_WRITE_TX_ADDR_CMD: Write RF_SETUP register to config data rate and transmit power
            // Byte 1: command
            // Byte 2: value
            // ------------------------------------
            `STATE_WRITE_TX_ADDR_CMD: begin
                nrf_csn = 1'b0;
                // Byte 1: Write TX_ADDR register command
                if (!start_cmd_flag) begin
                    // Set address byte counter: 4 (MSB) down to 0 (LSB)
                    address_byte_counter <= 3'd4; 
                    
                    spi_data_in = `CMD_W_REGISTER | `REG_TX_ADDR; 
                    spi_start = 1'b1;
                    start_cmd_flag = 1'b1;
                end
                
                // Command complete, move to sending address bytes
                if (spi_transfer_done && start_cmd_flag) begin
                    status_reg_out = spi_data_out;
                    start_cmd_flag = 1'b0;
                    // Keep CSN low to send next 5 address bytes
                    next_state = `STATE_WRITE_TX_ADDR_BYTE; 
                end
            end
            
            // ------------------------------------
            // STATE_WRITE_TX_ADDR_BYTE: Write the 5 address bytes sequentially (MSB first)
            // ------------------------------------
            `STATE_WRITE_TX_ADDR_BYTE: begin
                nrf_csn = 1'b0; // Keep CSN low during 5-byte write
                
                // Select address byte based on counter
                case (address_byte_counter)
                    3'd4: spi_data_in = `ADDR_BYTE_4; // MSB
                    3'd3: spi_data_in = `ADDR_BYTE_3;
                    3'd2: spi_data_in = `ADDR_BYTE_2;
                    3'd1: spi_data_in = `ADDR_BYTE_1;
                    3'd0: spi_data_in = `ADDR_BYTE_0; // LSB
                    default: spi_data_in = 8'h00;
                endcase
                
                spi_start = 1'b1; // Signal SPI to start transfer data
                
                if (spi_transfer_done) begin
                    status_reg_out = spi_data_out;
                    
                    if (address_byte_counter == 3'd0) begin
                        // Finish sending the last byte
                        next_state = `STATE_INIT_DONE;
                        nrf_csn = 1'b1;
                    end else begin
                        address_byte_counter <= address_byte_counter - 1;
                        next_state = `STATE_WRITE_TX_ADDR_BYTE; // Loopback to current state
                        nrf_csn = 1'b0;
                    end
                end
            end
            
            // ------------------------------------
            // STATE_INIT_DONE: Initialization sequence completed
            // ------------------------------------
            `STATE_INIT_DONE: begin
                nrf_csn = 1'b1; // CSN high
                nrf_ce = 1'b0;  // CE low (Standby-I)
                start_cmd_flag = 1'b0;
                
                cmd_done = 1'b1; // Signal cmd completed
                
                next_state = `STATE_SET_RX_MODE; // Return to rx state
            end
            
            // ------------------------------------
            // STATE_SET_RX_MODE: Explicitly config CONFIG reg for RX mode (PWR_UP=1, PRIM_RX=1)
            // ------------------------------------
            `STATE_SET_RX_MODE: begin
                nrf_csn = 1'b0;
                nrf_ce = 1'b0; // Ensure CE is low during config write
                if (!start_cmd_flag) begin
                    spi_data_in = `CMD_W_REGISTER | `REG_CONFIG;
                    spi_start = 1'b1;
                    start_cmd_flag = 1'b1;
                end
                if (spi_transfer_done && start_cmd_flag) begin
                    spi_data_in = 8'h0F; // CONFIG: PWR_UP=1, PRIM_RX=1 (RX mode)
                    spi_start = 1'b1;
                    if (spi_transfer_done) begin
                        start_cmd_flag = 1'b0;
                        nrf_csn = 1'b1;
                        nrf_ce = 1'b1;
                        next_state = `STATE_RX_WAIT; 
                    end
                end
            end
            
            // ------------------------------------
            // STATE_FLUSH_RX: Execute the FLUSH_RX command to clear the RX FIFO
            // ------------------------------------
            `STATE_FLUSH_RX: begin
                nrf_csn = 1'b0;
                nrf_ce = 1'b0; // Stop radio for safe command execution
                // FLUSH_RX cmd (0xE2)
                if (!start_cmd_flag) begin
                    spi_data_in = `CMD_FLUSH_RX; 
                    spi_start = 1'b1;
                    start_cmd_flag = 1'b1;
                end
                
                // Command FLUSH requires only 1 byte
                if (spi_transfer_done && start_cmd_flag) begin
                    status_reg_out = spi_data_out; // Status read during command
                    start_cmd_flag = 1'b0;
                    nrf_csn = 1'b1;
                    
                    next_state = `STATE_RX_WAIT; // Switch to data waiting mode
                end
            end
            
            // ------------------------------------
            // STATE_RX_WAIT: Main RX loop, waiting for NRF_IRQ to go low
            // ------------------------------------
            `STATE_RX_WAIT: begin
                if (nrf_irq == 1'b0) begin // Interrupt detected
                    // Pull CE low to stop radio and read data safely
                    nrf_ce = 1'b0; 
                    next_state = `STATE_RX_READ_STATUS; 
                end else begin
                    next_state = `STATE_RX_WAIT;
                end
            end
            
            // ------------------------------------
            // STATE_RX_READ_STATUS: Read the STATUS reg to confirm RX_DR flag
            // ------------------------------------
            `STATE_RX_READ_STATUS: begin
                nrf_csn = 1'b0;
                spi_data_in = `CMD_R_REGISTER | `REG_STATUS; // Read STATUS reg command
                spi_start = 1'b1;
                
                if (spi_transfer_done) begin
                    status_reg_out = spi_data_out; // Save status
                    // Check RX_DR bit (bit 6) of Status Register
                    if (spi_data_out[6] == 1'b1) begin
                        // RX_DR is set, data is ready -> read payload
                        payload_byte_counter = 3'd5; // Start counting down 6 bytes (5 to 0)
                        next_state = `STATE_RX_READ_PAYLOAD_CMD;
                    end else begin
                        // RX_DR not set -> must be TX_DS or MAX_RT -> clear general IRQ flags
                        next_state = `STATE_RX_CLEAR_IRQ;
                    end
                    nrf_csn = 1'b1;
                end
            end
            
            // ------------------------------------
            // STATE_RX_READ_PAYLOAD_CMD: Send the R_RX_PAYLOAD command.
            // ------------------------------------
            `STATE_RX_READ_PAYLOAD_CMD: begin
                nrf_csn = 1'b0;
                spi_data_in = `CMD_R_RX_PAYLOAD; // Read payload command
                spi_start = 1'b1;
                
                if (spi_transfer_done) begin
                    status_reg_out = spi_data_out; // Status read again during this command
                    next_state = `STATE_RX_READ_PAYLOAD_BYTE; // Move to reading 6 data bytes
                end
            end
            
            // ------------------------------------
            // STATE_RX_READ_PAYLOAD_BYTE: Read the 6 payload bytes sequentially.
            // ------------------------------------
            `STATE_RX_READ_PAYLOAD_BYTE: begin
                nrf_csn = 1'b0;
                spi_data_in = 8'h00; // Send 0x00 (dummy byte) to clock out data
                spi_start = 1'b1;
                
                if (spi_transfer_done) begin
                    rx_byte_out = spi_data_out; // Received data
                    rx_byte_count = payload_byte_counter; // Byte count
                    rx_data_valid = 1'b1; // Signal valid data byte
                    
                    if (payload_byte_counter == 3'd0) begin
                        // Finish read 6 bytes
                        next_state = `STATE_RX_CLEAR_IRQ;
                        nrf_csn = 1'b1;
                    end else begin
                        // Loopback: continue read
                        payload_byte_counter <= payload_byte_counter - 1; 
                        next_state = `STATE_RX_READ_PAYLOAD_BYTE;
                    end
                end
            end
            
            // ------------------------------------
            // STATE_RX_CLEAR_IRQ: Write STATUS register to clear interrupt flags (RX_DR, TX_DS, MAX_RT)
            // ------------------------------------
            `STATE_RX_CLEAR_IRQ: begin
                nrf_csn = 1'b0;
                nrf_ce = 1'b0;
                
                // Byte 1: Write STATUS reg command
                if (!start_cmd_flag) begin
                    spi_data_in = `CMD_W_REGISTER | `REG_STATUS;
                    spi_start = 1'b1;
                    start_cmd_flag = 1'b1;
                end
                
                // Byte 2: Data byte (Clear RX_DR, TX_DS, MAX_RT)
                if (spi_transfer_done && start_cmd_flag) begin
                    spi_data_in = 8'b01110000; // Clear RX_DR (bit 6), TX_DS (bit 5), MAX_RT (bit 4)
                    spi_start = 1'b1;
                    
                    if (spi_transfer_done) begin
                        start_cmd_flag = 1'b0;
                        nrf_csn = 1'b1;
                        nrf_ce = 1'b1;
                        next_state = `STATE_RX_WAIT; // Return to RX waiting mode
                    end
                end
            end
            
            default: next_state = `STATE_IDLE;
        endcase
    end
    
    // Sequential logic (only update status registers)
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
            spi_cmd_phase <= 1'b0;
            address_byte_counter <= 3'h0;
            payload_byte_counter <= 3'h0;
            power_up_delay_counter <= 24'h0;
            rx_data_valid <= 1'b0;
        end else begin
            // Update power-up delay counter
            if (current_state == `STATE_INIT_START && power_up_delay_counter < POWER_UP_DELAY) begin
                power_up_delay_counter <= power_up_delay_counter + 1;
            end
            // --- Update sequential logic
            current_state <= next_state;
            
            // update regs not handled in combinational logic
            if (current_state != next_state) begin
                 // Reset flags when state changes
                 start_cmd_flag <= 1'b0; 
                 spi_start <= 1'b0;
            end
            
            // Update regs based on combinational logic
            if (current_state == `STATE_WRITE_TX_ADDR_BYTE && spi_transfer_done && address_byte_counter != 3'd0) begin
                address_byte_counter <= address_byte_counter - 1;
            end
            
            if (current_state == `STATE_RX_READ_PAYLOAD_BYTE && spi_transfer_done && payload_byte_counter != 3'd0) begin
                payload_byte_counter <= payload_byte_counter - 1;
            end
            
        end
    end
    
endmodule