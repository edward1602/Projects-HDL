module spi_master (
    // Clock and Reset
    input clk,
    input rst_n,
    
    // SCK frequency divider parameter
    input [7:0] spi_clk_div,
    
    // Controller interface
    input start_transfer,
    output reg transfer_done,
    
    // Data interface
    input [7:0] data_in,
    output reg [7:0] data_out,

    // SPI interface
    output reg spi_sck, // reg because controlled in always block
    output reg spi_mosi, // reg because controlled in always block
    input spi_miso
);

    // State definition
    `define IDLE     2'b00
    `define TRANSMIT 2'b01
    `define DONE     2'b10
    
    // State registers
    reg [1:0] current_state, next_state;
    
    // SPI clock counter
    reg [7:0] sck_counter;
    
    // SCK tick signal
    reg sck_tick; 
    
    // Bit counter
    reg [3:0] bit_counter;
    
    // Temporary data registers
    reg [7:0] shift_reg_tx, shift_reg_rx;

    // ----------------------------------------------------
    // 1. Combinational Next State Logic
    // ----------------------------------------------------
    always @(current_state or start_transfer or bit_counter) begin
        next_state = current_state; // Default: maintain current state
        case (current_state)
            `IDLE: begin
                if (start_transfer) // Get cmd from controller
                    next_state = `TRANSMIT;
            end
    
            `TRANSMIT: begin
                if (bit_counter == 8) // Done transmit 1 byte (8 bits) 
                    next_state = `DONE;
            end
    
            `DONE: begin
                next_state = `IDLE;
            end
            default: next_state = `IDLE;
        endcase
    end
    
    // ----------------------------------------------------
    // 2. Sequential Logic (Clock, Shift registers, State registers)
    // ----------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            current_state <= `IDLE;
            transfer_done <= 1'b0;
            bit_counter <= 4'h0;
            shift_reg_tx <= 8'h00;
            shift_reg_rx <= 8'h00;
            data_out <= 8'h00;
            
            sck_counter <= 8'h00;
            spi_sck <= 1'b0;
            sck_tick <= 1'b0;
            spi_mosi <= 1'b0;
        end else begin
            // Update state
            current_state <= next_state;
            transfer_done <= 1'b0; // Default is low
    
            // SCK generation and tick logic
            if (current_state == `TRANSMIT) begin
                if (sck_counter == spi_clk_div - 1) begin
                    sck_counter <= 8'h00;
                    spi_sck <= ~spi_sck; 
                    sck_tick <= 1'b1;
                end else begin
                    sck_counter <= sck_counter + 1;
                    sck_tick <= 1'b0;
                end
            end else begin
                // Ensure SCK is low when IDLE/DONE
                spi_sck <= 1'b0; 
                sck_counter <= 8'h00;
                sck_tick <= 1'b0;
            end
    
            // FSM logic
            case (current_state)
                `IDLE: begin
                    if (start_transfer) begin
                        shift_reg_tx <= data_in; // Load input data
                        bit_counter <= 4'h0;
                    end
                    spi_mosi <= 1'b0; // MOSI low when IDLE
                end
    
                `TRANSMIT: begin
                    // Generate MOSI: Send MSB first
                    spi_mosi <= shift_reg_tx[7];
                    
    
                    // Shift on rising edge of SCK (CPOL=0, CPHA=0)
                    if (sck_tick & spi_sck) begin // Check (sck_tick=1) and (spi_sck=1)
                        shift_reg_tx <= shift_reg_tx << 1; 
                        shift_reg_rx <= {shift_reg_rx[6:0], spi_miso}; 
                        bit_counter <= bit_counter + 1;
                    end
                    
                end
    
                `DONE: begin
                    data_out <= shift_reg_rx;
                    transfer_done <= 1'b1;
                    spi_mosi <= 1'b0;
                    $display("[SPI] Done. Data_out %h", data_out);
                end
            endcase
        end
    end
endmodule