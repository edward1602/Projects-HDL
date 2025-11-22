`timescale 1ns / 1ps

 module spi_master(
    input wire clk,
    input wire reset,
    input wire start,
    input wire [7:0] data_tx,
    output reg [7:0] data_rx,
    output reg busy,
    output reg sck,
    output reg mosi, // Master Out Slave In: master send - slave get
    input wire miso // Master In Slave Out: master get - slave send
    );
    parameter CLK_DIV = 50;
    
    reg [5:0] clk_counter;
    reg [3:0] bit_counter;
    reg [7:0] tx_buffer;
    reg [7:0] rx_buffer;
    
    localparam IDLE = 0, TRANSFER = 1, DONE = 2;
    reg [1:0] state;
        
    always @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
            busy <= 0;
            sck <= 0;
            mosi <= 0;
            bit_counter <= 0;
            clk_counter <= 0;
        end else begin
            case (state)
                IDLE: begin
                    busy <= 0;
                    sck <= 0;
                    if (start) begin
                        tx_buffer <= data_tx;
                        bit_counter <= 0;
                        clk_counter <= 0;
                        busy <= 1;
                        state <= TRANSFER;
                    end
                end
                
                TRANSFER: begin
                    if (clk_counter == CLK_DIV - 1) begin
                        clk_counter <= 0;
                        sck <= ~sck;
                        
                        if (sck == 0) begin
                            mosi <= tx_buffer[7 - bit_counter];
                        end else begin
                            rx_buffer[7 - bit_counter] <= miso;
                            bit_counter <= bit_counter + 1;
                            
                            if (bit_counter == 7) begin
                                state <= DONE;
                            end
                        end
                    end else begin
                        clk_counter <= clk_counter + 1;
                    end
                end
                
                DONE: begin
                    data_rx <= rx_buffer;
                    busy <= 0;
                    sck <= 0;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule
