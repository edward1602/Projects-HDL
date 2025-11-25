module spi_master (
    // Clock và Reset
    input clk,
    input rst_n,
    
    // Tham s? chia t?n s? SCK
    input [7:0] spi_clk_div, 
    
    // COntroller
    input start_transfer,
    output reg transfer_done,
    
    // Output
    input [7:0] data_in,
    output reg [7:0] data_out,

    // Giao di?n SPI
    output reg spi_sck, // reg vì ???c ?i?u khi?n trong always
    output reg spi_mosi, // reg vì ???c ?i?u khi?n trong always
    input spi_miso
);

    // ??nh ngh?a các h?ng s? tr?ng thái (thay vì enum)
    `define IDLE     2'b00
    `define TRANSMIT 2'b01
    `define DONE     2'b10
    
    // Các thanh ghi tr?ng thái (reg)
    reg [1:0] current_state, next_state;
    
    // B? ??m xung ??ng h? SPI (reg)
    reg [7:0] sck_counter;
    
    // Tín hi?u ?ánh d?u s? ki?n SCK (reg)
    reg sck_tick; 
    
    // B? ??m bit (reg)
    reg [3:0] bit_counter;
    
    // Thanh ghi t?m th?i cho d? li?u (reg)
    reg [7:0] shift_reg_tx, shift_reg_rx;

    // ----------------------------------------------------
    // 1. Logic Chuy?n tr?ng thái t? h?p (next_state logic)
    // ----------------------------------------------------
    always @(current_state or start_transfer or bit_counter) begin
        next_state = current_state; // M?c ??nh gi? nguyên tr?ng thái
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
    // 2. Logic Tu?n t? (Xung clock, D?ch chuy?n, ??ng ký tr?ng thái)
    // ----------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset
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
            // C?p nh?t tr?ng thái
            current_state <= next_state;
            transfer_done <= 1'b0; // M?c ??nh là th?p
    
            // Logic Xung SCK và Tick
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
                // ??m b?o SCK ? m?c th?p khi IDLE/DONE
                spi_sck <= 1'b0; 
                sck_counter <= 8'h00;
                sck_tick <= 1'b0;
            end
    
            // Logic FSM
            case (current_state)
                `IDLE: begin
                    if (start_transfer) begin
                        shift_reg_tx <= data_in; // Download data_in
                        bit_counter <= 4'h0;
                    end
                    spi_mosi <= 1'b0; // MOSI th?p khi IDLE
                end
    
                `TRANSMIT: begin
                    // T?o MOSI: G?i bit MSB tr??c
                    spi_mosi <= shift_reg_tx[7];
                    
    
                    // D?ch chuy?n trên c?nh LÊN c?a SCK (CPOL=0, CPHA=0)
                    if (sck_tick & spi_sck) begin // Ki?m tra (sck_tick=1) và (spi_sck=1)
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