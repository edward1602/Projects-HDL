`timescale 1ns / 1ps

module nrf24l01_controller(
input wire clk,
    input wire reset,
    output reg [7:0] payload_0,
    output reg [7:0] payload_1,
    output reg [7:0] payload_2,
    output reg [7:0] payload_3,
    output reg [7:0] payload_4,
    output reg [7:0] payload_5,
    output reg data_ready,
    output reg spi_start,
    output reg [7:0] spi_tx,
    input wire [7:0] spi_rx,
    input wire spi_busy,
    output reg ce,
    output reg csn
    );
    localparam CMD_R_RX_PAYLOAD = 8'h61;
    localparam CMD_NOP = 8'hFF;
    
    localparam INIT = 0, IDLE = 1, CHECK_STATUS = 2, 
               READ_PAYLOAD = 3, PROCESS = 4;
    reg [3:0] state;
    reg [5:0] byte_count;
    reg [23:0] delay_counter;
    
    always @(posedge clk) begin
        if (reset) begin
            state <= INIT;
            ce <= 0;
            csn <= 1;
            data_ready <= 0;
            spi_start <= 0;
            delay_counter <= 0;
            byte_count <= 0;
        end else begin
            case (state)
                INIT: begin
                    if (delay_counter < 10000000) begin
                        delay_counter <= delay_counter + 1;
                    end else begin
                        ce <= 1;
                        state <= IDLE;
                        delay_counter <= 0;
                    end
                end
                
                IDLE: begin
                    data_ready <= 0;
                    if (delay_counter < 1000000) begin
                        delay_counter <= delay_counter + 1;
                    end else begin
                        delay_counter <= 0;
                        state <= CHECK_STATUS;
                    end
                end
                
                CHECK_STATUS: begin
                    if (!spi_busy) begin
                        csn <= 0;
                        spi_tx <= CMD_NOP;
                        spi_start <= 1;
                        state <= READ_PAYLOAD;
                    end
                end
                
                READ_PAYLOAD: begin
                    spi_start <= 0;
                    if (!spi_busy && byte_count == 0) begin
                        if (spi_rx[6]) begin
                            spi_tx <= CMD_R_RX_PAYLOAD;
                            spi_start <= 1;
                            byte_count <= 1;
                        end else begin
                            csn <= 1;
                            state <= IDLE;
                        end
                    end else if (!spi_busy && byte_count > 0 && byte_count <= 6) begin
                        case (byte_count - 1)
                            0: payload_0 <= spi_rx;
                            1: payload_1 <= spi_rx;
                            2: payload_2 <= spi_rx;
                            3: payload_3 <= spi_rx;
                            4: payload_4 <= spi_rx;
                            5: payload_5 <= spi_rx;
                        endcase
                        
                        if (byte_count < 6) begin
                            spi_tx <= 8'h00;
                            spi_start <= 1;
                            byte_count <= byte_count + 1;
                        end else begin
                            csn <= 1;
                            byte_count <= 0;
                            state <= PROCESS;
                        end
                    end
                end
                
                PROCESS: begin
                    data_ready <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule
