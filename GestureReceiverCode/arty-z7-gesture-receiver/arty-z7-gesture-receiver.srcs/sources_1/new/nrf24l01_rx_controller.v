module nrf24l01_simple_rx_controller #(
    parameter USE_IRQ = 1,
    // parameter POWER_UP_DELAY = 24'd1000,
    parameter [23:0] RX_POLL_INTERVAL = 24'd12_500_000 // ~100ms at 125MHz
) (
    input clk,
    input rst_n,
    
    // Simple control interface
    input start_rx,
    output reg rx_ready,
    
    // Physical interface to NRF24L01
    output reg nrf_ce,
    output reg nrf_csn,
    input nrf_irq,
    
    // SPI interface
    output wire spi_sck,
    output wire spi_mosi,
    input spi_miso,
    
    // Simple data output - complete 6-byte packet at once
    output reg [47:0] rx_payload,    // Complete 48-bit payload
    output reg payload_ready         // Flag: new payload available
);

    `include "nrf24l01_rx_defines.v"
    
    // SPI Master interface
    reg spi_start;
    reg [7:0] spi_data_in;
    wire spi_done;
    wire [7:0] spi_data_out;
    
    // Internal signals only
    
    // State machine
    reg [4:0] current_state, next_state;
    reg [26:0] power_up_counter;
    reg [2:0] address_byte_counter;
    reg [2:0] payload_byte_counter;
    reg spi_phase; // 0: command, 1: data
    reg [23:0] rx_poll_counter;
    
    // Payload assembly
    reg [7:0] payload_bytes [0:5];
    
    // RX address bytes (5 bytes, MSB first)
    wire [7:0] rx_address_bytes [0:4];
    assign rx_address_bytes[0] = `ADDR_BYTE_0; // LSB
    assign rx_address_bytes[1] = `ADDR_BYTE_1;
    assign rx_address_bytes[2] = `ADDR_BYTE_2;
    assign rx_address_bytes[3] = `ADDR_BYTE_3;
    assign rx_address_bytes[4] = `ADDR_BYTE_4; // MSB
    
    // Timing parameters (for hardware - 100ms power-up delay)
//     parameter POWER_UP_DELAY = 24'd12_500_000; // 100ms at 125MHz for hardware
    parameter [26:0] POWER_UP_DELAY = 27'd62_500_000; // 500ms at 125MHz for hardware
//    parameter POWER_UP_DELAY = 24'd0; // For testbench

    // SPI clock divider for ~500kHz (125MHz / 250 = 500kHz)
    parameter SPI_CLK_DIVIDER = 8'd250;
    
    // SPI Master instantiation
    spi_master spi_master_inst (
        .clk(clk),
        .rst_n(rst_n),
        .spi_clk_div(SPI_CLK_DIVIDER),
        .start_transfer(spi_start),
        .data_in(spi_data_in),
        .transfer_done(spi_done),
        .data_out(spi_data_out),
        .spi_sck(spi_sck),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso)
    );
    
    // Note: Payload assembler can be instantiated externally if needed
    // This module only handles NRF24L01 communication and provides raw payload
    
    // Next state logic (combinational)
    always @(*) begin
        next_state = current_state;
        
        case (current_state)
            `STATE_IDLE: begin
                if (start_rx) 
                    next_state = `STATE_INIT_START;
                    $display("[NRF] idle -> init_start");
            end
            
            `STATE_INIT_START: begin
                if (power_up_counter >= POWER_UP_DELAY)
                    next_state = `STATE_WRITE_CONFIG;
                    $display("[NRF] init_start -> write_config");
            end
            
            `STATE_WRITE_CONFIG: begin
                if (spi_done && spi_phase)
                    next_state = `STATE_WRITE_EN_RXADDR;
                    $display("[NRF] write_config -> write_en_rxaddr");
            end
            
            `STATE_WRITE_EN_RXADDR: begin
                if (spi_done && spi_phase)
                    next_state = `STATE_WRITE_SETUP_AW;
                    $display("[NRF] write_en_rxaddr -> write_setup_aw");
            end
            
            `STATE_WRITE_SETUP_AW: begin
                if (spi_done && spi_phase)
                    next_state = `STATE_WRITE_RF_CH;
                    $display("[NRF] write_setup_aw -> write_rf_ch");
            end
            
            `STATE_WRITE_RF_CH: begin
                if (spi_done && spi_phase)
                    next_state = `STATE_WRITE_RF_SETUP;
                    $display("[NRF] write_rf_ch -> write_rf_setup");
            end
            
            `STATE_WRITE_RF_SETUP: begin
                if (spi_done && spi_phase)
                    next_state = `STATE_WRITE_RX_PW;
                    $display("[NRF] write_rf_setup -> write_rx_pw");
            end
            
            `STATE_WRITE_RX_PW: begin
                if (spi_done && spi_phase)
                    next_state = `STATE_WRITE_RX_ADDR_CMD;
                    $display("[NRF] write_rx_pw -> write_rx_addr_cmd");
            end
            
            `STATE_WRITE_RX_ADDR_CMD: begin
                if (spi_done)
                    next_state = `STATE_WRITE_RX_ADDR_BYTE;
                    $display("[NRF] write_rx_addr_cmd -> write_rx_addr_byte");
            end
            
            `STATE_WRITE_RX_ADDR_BYTE: begin
                if (spi_done && (address_byte_counter >= 4))
                    next_state = `STATE_RX_READY;
                    $display("[NRF] write_rx_addr_byte -> rx_ready");
            end
            
            `STATE_RX_READY: begin
                if (USE_IRQ) begin
                    if (!nrf_irq) begin // IRQ is active low
                        next_state = `STATE_RX_READ_PAYLOAD_CMD;
                        $display("[NRF] rx_ready -> rx_read_payload_cmd (IRQ detected)");
                    end
                end else begin
                    if (rx_poll_counter >= RX_POLL_INTERVAL) begin
                        next_state = `STATE_RX_STATUS_CMD;
                        $display("[NRF] rx_ready -> rx_status_cmd (poll timeout)");
                    end
                end
            end

            `STATE_RX_STATUS_CMD: begin
                if (spi_done) begin
                    next_state = `STATE_RX_STATUS_READ;
                    $display("[NRF] rx_status_cmd -> rx_status_read");
                end
            end

            `STATE_RX_STATUS_READ: begin
                if (spi_done) begin
                    if (spi_data_out[6]) begin
                        next_state = `STATE_RX_READ_PAYLOAD_CMD;
                        $display("[NRF] rx_status_read -> rx_read_payload_cmd (RX_DR set)");
                    end else begin
                        next_state = `STATE_RX_READY;
                        $display("[NRF] rx_status_read -> rx_ready (no data)");
                    end
                end
            end

            `STATE_RX_READ_PAYLOAD_CMD: begin
                if (spi_done) begin
                    next_state = `STATE_RX_READ_PAYLOAD_BYTE;
                    $display("[NRF] rx_read_payload_cmd -> rx_read_payload_byte");
                end
            end
            
            `STATE_RX_READ_PAYLOAD_BYTE: begin
                if (spi_done && (payload_byte_counter >= 5)) begin
                    next_state = `STATE_RX_CLEAR_IRQ;
                    $display("[NRF] rx_read_payload_byte -> rx_clear_irq (payload complete)");
                end
            end
            
            `STATE_RX_CLEAR_IRQ: begin
                if (spi_done && spi_phase) begin
                    next_state = `STATE_RX_READY;
                    $display("[NRF] rx_clear_irq -> rx_ready (back to listening)");
                end
            end
            
            default: next_state = `STATE_IDLE;
        endcase
    end
    
    // Output control logic (combinational)
    always @(*) begin
        // Defaults
        nrf_csn = 1'b1;
        spi_start = 1'b0;
        spi_data_in = 8'h00;
        
        case (current_state)
            `STATE_INIT_START: begin
                // Keep CE low during initialization
                nrf_csn = 1'b1;
            end
            
            `STATE_WRITE_CONFIG: begin
                nrf_csn = 1'b0;
                if (!spi_phase) begin
                    spi_data_in = `CMD_W_REGISTER | `REG_CONFIG;
                    spi_start = 1'b1;
                end else begin
                    spi_data_in = `VAL_CONFIG_RX_ONLY;
                    spi_start = 1'b1;
                end
            end
            
            `STATE_WRITE_EN_RXADDR: begin
                nrf_csn = 1'b0;
                if (!spi_phase) begin
                    spi_data_in = `CMD_W_REGISTER | `REG_EN_RXADDR;
                    spi_start = 1'b1;
                end else begin
                    spi_data_in = `VAL_EN_RXADDR;
                    spi_start = 1'b1;
                end
            end
            
            `STATE_WRITE_SETUP_AW: begin
                nrf_csn = 1'b0;
                if (!spi_phase) begin
                    spi_data_in = `CMD_W_REGISTER | `REG_SETUP_AW;
                    spi_start = 1'b1;
                end else begin
                    spi_data_in = `VAL_SETUP_AW;
                    spi_start = 1'b1;
                end
            end
            
            `STATE_WRITE_RF_CH: begin
                nrf_csn = 1'b0;
                if (!spi_phase) begin
                    spi_data_in = `CMD_W_REGISTER | `REG_RF_CH;
                    spi_start = 1'b1;
                end else begin
                    spi_data_in = `VAL_RF_CH;
                    spi_start = 1'b1;
                end
            end
            
            `STATE_WRITE_RF_SETUP: begin
                nrf_csn = 1'b0;
                if (!spi_phase) begin
                    spi_data_in = `CMD_W_REGISTER | `REG_RF_SETUP;
                    spi_start = 1'b1;
                end else begin
                    spi_data_in = `VAL_RF_SETUP;
                    spi_start = 1'b1;
                end
            end
            
            `STATE_WRITE_RX_PW: begin
                nrf_csn = 1'b0;
                if (!spi_phase) begin
                    spi_data_in = `CMD_W_REGISTER | `REG_RX_PW_P0;
                    spi_start = 1'b1;
                end else begin
                    spi_data_in = `VAL_RX_PW_P0;
                    spi_start = 1'b1;
                end
            end
            
            `STATE_WRITE_RX_ADDR_CMD: begin
                nrf_csn = 1'b0;
                spi_data_in = `CMD_W_REGISTER | `REG_RX_ADDR_P0;
                spi_start = 1'b1;
            end
            
            `STATE_WRITE_RX_ADDR_BYTE: begin
                nrf_csn = 1'b0;
                spi_data_in = rx_address_bytes[address_byte_counter];
                spi_start = 1'b1;
            end
            
            `STATE_RX_READ_PAYLOAD_CMD: begin
                nrf_csn = 1'b0;
                spi_data_in = `CMD_R_RX_PAYLOAD;
                spi_start = 1'b1;
            end
            
            `STATE_RX_READ_PAYLOAD_BYTE: begin
                nrf_csn = 1'b0;
                spi_data_in = 8'h00; // Dummy data for reading
                spi_start = 1'b1;
            end
            
            `STATE_RX_CLEAR_IRQ: begin
                nrf_csn = 1'b0;
                if (!spi_phase) begin
                    spi_data_in = `CMD_W_REGISTER | `REG_STATUS;
                    spi_start = 1'b1;
                end else begin
                    spi_data_in = 8'h70; // Clear RX_DR, TX_DS, MAX_RT
                    spi_start = 1'b1;
                end
            end
            
            `STATE_RX_STATUS_CMD: begin
                nrf_csn = 1'b0;
                spi_data_in = `CMD_R_REGISTER | `REG_STATUS;
                spi_start = 1'b1;
            end
            
            `STATE_RX_STATUS_READ: begin
                nrf_csn = 1'b0;
                spi_data_in = 8'h00; // Dummy read
                spi_start = 1'b1;
            end
            
            default: begin
                nrf_csn = 1'b1;
                spi_start = 1'b0;
            end
        endcase
    end
    
    // Sequential logic for state updates and counters
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= `STATE_IDLE;
            power_up_counter <= 0;
            spi_phase <= 1'b0;
            address_byte_counter <= 0;
            payload_byte_counter <= 0;
            rx_ready <= 1'b0;
            payload_ready <= 1'b0; // CHỈ RESET KHI RESET TOÀN BỘ HỆ TH�?NG
            rx_payload <= 48'h0;
            nrf_ce <= 1'b0;
            rx_poll_counter <= 24'h0;
        end else begin
            current_state <= next_state;
            payload_ready <= 1'b0; // default low; pulses high when full payload received
            // payload_ready no longer latches high across cycles
            
            // Power-up delay counter
            if (current_state == `STATE_INIT_START && power_up_counter < POWER_UP_DELAY) begin
                power_up_counter <= power_up_counter + 1;
            end
            
            // SPI phase management for register writes
            if (spi_done) begin
                case (current_state)
                    `STATE_WRITE_CONFIG,
                    `STATE_WRITE_EN_RXADDR,
                    `STATE_WRITE_SETUP_AW,
                    `STATE_WRITE_RF_CH,
                    `STATE_WRITE_RF_SETUP,
                    `STATE_WRITE_RX_PW: begin
                        spi_phase <= ~spi_phase; // Toggle phase for 2-byte register writes
                    end
                    `STATE_RX_CLEAR_IRQ: begin
                        spi_phase <= ~spi_phase; // Toggle for STATUS register write
                    end
                    default: begin
                        spi_phase <= 1'b0; // Reset for other operations
                    end
                endcase
            end
            
            // Address byte counter
            if (current_state == `STATE_WRITE_RX_ADDR_BYTE && spi_done) begin
                if (address_byte_counter < 4) begin
                    $display("[NRF] Address byte %0d sent: 0x%h", address_byte_counter, rx_address_bytes[address_byte_counter]);
                    address_byte_counter <= address_byte_counter + 1;
                end else begin
                    $display("[NRF] All address bytes sent, initialization complete!");
                    address_byte_counter <= 0; // Reset for next time
                end
            end

            if (current_state == `STATE_RX_STATUS_READ && spi_done) begin
                $display("[NRF] STATUS register: 0x%02h", spi_data_out);
            end
            
            // Payload byte counter and data capture
            if (current_state == `STATE_RX_READ_PAYLOAD_BYTE && spi_done) begin
                $display("[NRF] Payload byte %0d received: 0x%h", payload_byte_counter, spi_data_out);
                // Store received byte in little-endian format
                case (payload_byte_counter)
                    0: rx_payload[7:0] <= spi_data_out;
                    1: rx_payload[15:8] <= spi_data_out;
                    2: rx_payload[23:16] <= spi_data_out;
                    3: rx_payload[31:24] <= spi_data_out;
                    4: rx_payload[39:32] <= spi_data_out;
                    5: rx_payload[47:40] <= spi_data_out;
                endcase
                payload_byte_counter <= payload_byte_counter + 1;
                
                // Check if all 6 bytes received (counter will be 6 after last byte)
                if (payload_byte_counter == 5) begin
                    $display("[NRF] *** PACKET RECEIVED SUCCESSFULLY! ***");
                    $display("[NRF] Complete payload: 0x%h", {spi_data_out, rx_payload[39:0]});
                    payload_ready <= 1'b1; // pulse high when packet completes
                    payload_byte_counter <= 0; // Reset for next packet
                end
            end
            
            // RX ready flag and CE control
            if (current_state == `STATE_RX_READY) begin
                if (!rx_ready) begin
                    $display("[NRF] ===============================");
                    $display("[NRF] RX MODE READY - LISTENING FOR PACKETS!");
                    $display("[NRF] Channel: 76 (2.476GHz), Data Rate: 250Kbps, Address: 0xE7E7E7E7E7");
                    $display("[NRF] ===============================");
                end
                rx_ready <= 1'b1;
                nrf_ce <= 1'b1; // Enable RX mode
                if (!USE_IRQ) begin
                    if (rx_poll_counter < RX_POLL_INTERVAL)
                        rx_poll_counter <= rx_poll_counter + 1;
                    else
                        rx_poll_counter <= 24'h0;
                end else begin
                    rx_poll_counter <= 24'h0;
                end
            end else begin
                if (current_state == `STATE_IDLE) begin
                    rx_ready <= 1'b0;
                end
                nrf_ce <= 1'b0; // CE phải thấp khi không ở trạng thái lắng nghe
                rx_poll_counter <= 24'h0;
            end
        end
    end
endmodule