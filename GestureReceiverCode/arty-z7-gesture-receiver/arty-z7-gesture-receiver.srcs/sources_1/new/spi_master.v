module spi_master (
    input wire clk,             // 125 MHz
    input wire rst,
    input wire start,
    input wire [7:0] data_in,
    output reg [7:0] data_out,
    output reg done,
    
    output reg sck,
    output reg mosi,
    input wire miso
);
    // 125MHz / 64 ~= 2MHz (T?c ?? an toàn cho dây n?i dài)
    parameter CLK_DIV = 6; 
    reg [CLK_DIV-1:0] clk_cnt;
    wire sck_en = (clk_cnt == 0);
    
    reg [3:0] bit_cnt;
    reg [1:0] state;
    reg [7:0] shift_reg;

    localparam IDLE = 0, TRANSFER = 1;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            clk_cnt <= 0; sck <= 0;
        end else begin
            clk_cnt <= clk_cnt + 1;
            if (state == TRANSFER) begin 
                if (clk_cnt == {1'b1, {(CLK_DIV-1){1'b0}}}) sck <= 1;
                else if (clk_cnt == 0) sck <= 0;
            end else sck <= 0;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE; mosi <= 0; done <= 0;
            bit_cnt <= 0; data_out <= 0; shift_reg <= 0;
        end else if (sck_en) begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        shift_reg <= data_in;
                        mosi <= data_in[7];
                        bit_cnt <= 0;
                        state <= TRANSFER;
                    end
                end
                TRANSFER: begin
                    if (bit_cnt == 7) begin
                        state <= IDLE;
                        done <= 1;
                        data_out <= {shift_reg[6:0], miso};
                    end else begin
                        shift_reg <= {shift_reg[6:0], miso};
                        mosi <= shift_reg[6];
                        bit_cnt <= bit_cnt + 1;
                    end
                end
            endcase
        end
    end
endmodule