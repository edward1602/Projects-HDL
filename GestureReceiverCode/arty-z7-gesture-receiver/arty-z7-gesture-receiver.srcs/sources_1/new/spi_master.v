module spi_master #(
    parameter PRESCALER = 50  // T?c ?? SPI = System_Clock / (2 * PRESCALER)
                              // Ví d?: Clk=50MHz, PRESCALER=25 -> SPI=1MHz
)(
    input  wire       clk,        // System Clock
    input  wire       rst_n,      // Reset Active Low
    input  wire       start,      // Xung kích ho?t b?t ??u g?i 1 byte
    input  wire [7:0] data_in,    // D? li?u c?n g?i (Tx)
    
    input  wire       miso,       // Master In Slave Out (t? nRF24L01)
    output wire       mosi,       // Master Out Slave In (t?i nRF24L01)
    output reg        sck,        // SPI Clock
    
    output reg [7:0]  data_out,   // D? li?u nh?n ???c (Rx)
    output reg        busy,       // =1 khi ?ang truy?n
    output reg        done        // B?t lên 1 trong 1 chu k? clock khi hoàn t?t
);

    // Các tr?ng thái FSM
    localparam IDLE  = 2'b00;
    localparam WORK  = 2'b01;
    
    reg [1:0] state;
    reg [7:0] tx_buffer;     // Thanh ghi d?ch truy?n
    reg [7:0] rx_buffer;     // Thanh ghi d?ch nh?n
    reg [3:0] bit_cnt;       // ??m s? bit ?ã truy?n (0-7)
    
    // B? ??m chia xung
    integer clk_cnt; 
    
    // Logic t?o c?nh xung cho SPI Mode 0
    // sample_edge: C?nh lên (Rising) -> nRF ??c d? li?u, FPGA ??c MISO
    // shift_edge:  C?nh xu?ng (Falling) -> FPGA ??y bit ti?p theo ra MOSI
    wire sample_edge = (clk_cnt == PRESCALER - 1);
    wire shift_edge  = (clk_cnt == (PRESCALER * 2) - 1);

    // Gán MOSI luôn là bit cao nh?t c?a tx_buffer
    assign mosi = tx_buffer[7];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= IDLE;
            sck         <= 1'b0;      // Mode 0: SCK idle LOW
            tx_buffer   <= 8'b0;
            rx_buffer   <= 8'b0;
            data_out    <= 8'b0;
            bit_cnt     <= 4'd0;
            clk_cnt     <= 0;
            busy        <= 1'b0;
            done        <= 1'b0;
        end else begin
            // M?c ??nh reset tín hi?u done
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    busy    <= 1'b0;
                    sck     <= 1'b0;
                    clk_cnt <= 0;
                    
                    if (start) begin
                        busy      <= 1'b1;
                        tx_buffer <= data_in; // Load d? li?u vào buffer
                        bit_cnt   <= 4'd0;
                        state     <= WORK;
                        // L?u ý: V?i Mode 0, bit MSB (bit 7) ph?i xu?t hi?n trên MOSI
                        // NGAY KHI start (tr??c c?nh lên SCK ??u tiên).
                        // Dòng "assign mosi = tx_buffer[7]" ?ã x? lý vi?c này.
                    end
                end

                WORK: begin
                    // B? ??m t?o xung SCK
                    if (clk_cnt < (PRESCALER * 2) - 1)
                        clk_cnt <= clk_cnt + 1;
                    else
                        clk_cnt <= 0;

                    // --- C?nh lên SCK (Sample MISO) ---
                    if (sample_edge) begin
                        sck <= 1'b1;
                        // Nh?n d? li?u t? nRF24L01 (d?ch vào t? bên ph?i - LSB)
                        rx_buffer <= {rx_buffer[6:0], miso}; 
                    end
                    
                    // --- C?nh xu?ng SCK (Shift MOSI) ---
                    else if (shift_edge) begin
                        sck <= 1'b0;
                        
                        if (bit_cnt == 4'd7) begin
                            // ?ã xong 8 bit
                            state     <= IDLE;
                            data_out  <= rx_buffer; // C?p nh?t d? li?u ??u ra
                            done      <= 1'b1;      // Báo hi?u xong
                        end else begin
                            // Ch?a xong, d?ch bit ti?p theo ?? chu?n b? cho l?n sample t?i
                            tx_buffer <= {tx_buffer[6:0], 1'b0}; 
                            bit_cnt   <= bit_cnt + 1;
                        end
                    end
                end
            endcase
        end
    end

endmodule