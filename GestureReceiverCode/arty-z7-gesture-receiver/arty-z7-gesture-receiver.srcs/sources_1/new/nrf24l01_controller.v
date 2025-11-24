`timescale 1ns / 1ps

module nrf24l01_controller #(
    parameter USE_IRQ = 0,          
    parameter DATA_RATE = "250K"    
)(
    input  wire        clk,            
    input  wire        reset,
    input  wire        nrf_irq,        

    output reg  [7:0] payload_0,
    output reg  [7:0] payload_1,
    output reg  [7:0] payload_2,
    output reg  [7:0] payload_3,
    output reg  [7:0] payload_4,
    output reg  [7:0] payload_5,
    output reg        data_ready,

    output reg        spi_start,
    output reg  [7:0] spi_tx,
    input  wire [7:0] spi_rx,
    input  wire       spi_busy,

    output reg        ce,
    output reg        csn
);

    // Commands & Registers
    localparam CMD_R_RX_PAYLOAD = 8'h61;
    localparam CMD_W_REGISTER   = 8'h20;
    localparam CMD_FLUSH_RX     = 8'hE2;
    localparam CMD_NOP          = 8'hFF;

    localparam REG_CONFIG     = 5'h00;
    localparam REG_EN_AA      = 5'h01;
    localparam REG_SETUP_AW   = 5'h03;
    localparam REG_RF_CH      = 5'h05;
    localparam REG_RF_SETUP   = 5'h06;
    localparam REG_STATUS     = 5'h07;
    localparam REG_RX_ADDR_P0 = 5'h0A;
    localparam REG_RX_PW_P0   = 5'h11;

    // FSM States
    localparam S_PWR_ON_DELAY   = 6'd0;
    localparam S_CONFIG_1       = 6'd5;
    localparam S_DELAY_2MS      = 6'd10;
    localparam S_WRITE_REGS     = 6'd15;
    localparam S_WRITE_ADDR     = 6'd20;
    localparam S_CONFIG_2       = 6'd25;
    localparam S_RX_MODE        = 6'd30;
    
    // Polling States
    localparam S_POLL_START     = 6'd35; 
    localparam S_POLL_WAIT      = 6'd36;
    localparam S_POLL_CHECK     = 6'd37;

    localparam S_READ_STATUS    = 6'd40;
    localparam S_READ_PAYLOAD   = 6'd45;
    localparam S_CLEAR_IRQ      = 6'd50;
    localparam S_FLUSH_RX       = 6'd55;
    localparam S_DATA_READY     = 6'd60;

    reg [5:0]  state;
    reg [23:0] delay_cnt;
    reg [3:0]  reg_idx;
    reg [2:0]  addr_idx;
    reg [2:0]  payload_idx;
    reg        irq_sync1, irq_sync2, irq_edge;

    wire [7:0] rf_setup_val = (DATA_RATE == "250K") ? 8'h27 :
                              (DATA_RATE == "1M")   ? 8'h06 : 8'h07;

    always @(posedge clk) begin
        irq_sync1 <= nrf_irq;
        irq_sync2 <= irq_sync1;
        irq_edge  <= irq_sync2 & ~irq_sync1; 
    end

    always @(posedge clk) begin
        if (reset) begin
            state       <= S_PWR_ON_DELAY;
            ce          <= 0;
            csn         <= 1;
            spi_start   <= 0;
            data_ready  <= 0;
            delay_cnt   <= 0;
            reg_idx     <= 0;
            addr_idx    <= 0;
            payload_idx <= 0;
        end else begin
            spi_start  <= 0;
            data_ready <= 0;

            case (state)
                S_PWR_ON_DELAY: begin
                    ce <= 0;
                    if (delay_cnt < 24'd10_000_000) delay_cnt <= delay_cnt + 1; 
                    else begin delay_cnt <= 0; state <= S_CONFIG_1; end
                end

                S_CONFIG_1: begin  
                    if (!spi_busy) begin
                        csn <= 0; spi_tx <= {CMD_W_REGISTER, REG_CONFIG}; spi_start <= 1;
                        state <= S_CONFIG_1 + 1;
                    end
                end
                S_CONFIG_1+1: begin
                    if (!spi_busy) begin 
                        spi_tx <= 8'h0E; spi_start <= 1; state <= S_CONFIG_1+2; 
                    end
                end
                S_CONFIG_1+2: begin 
                    if (!spi_busy) begin csn <= 1; state <= S_DELAY_2MS; end
                end

                S_DELAY_2MS: begin
                    if (delay_cnt < 24'd200_000) delay_cnt <= delay_cnt + 1; 
                    else begin delay_cnt <= 0; state <= S_WRITE_REGS; reg_idx <= 0; end   
                end

                S_WRITE_REGS: begin 
                    if (!spi_busy && reg_idx < 6) begin
                        csn <= 0;
                        case (reg_idx)
                            0: spi_tx <= {CMD_W_REGISTER, REG_EN_AA};       
                            1: spi_tx <= {CMD_W_REGISTER, REG_SETUP_AW};    
                            2: spi_tx <= {CMD_W_REGISTER, REG_RF_CH};       
                            3: spi_tx <= {CMD_W_REGISTER, REG_RF_SETUP};    
                            4: spi_tx <= {CMD_W_REGISTER, REG_RX_PW_P0};    
                            5: spi_tx <= {CMD_W_REGISTER, REG_RX_ADDR_P0};  
                        endcase
                        spi_start <= 1;
                        state <= S_WRITE_REGS + 1;
                    end else if (reg_idx == 6) begin
                        state <= S_WRITE_ADDR; 
                        addr_idx <= 0;
                    end
                end
                S_WRITE_REGS+1: if (!spi_busy) begin
                    case (reg_idx)
                        0: spi_tx <= 8'h00; // Disable AA
                        1: spi_tx <= 8'h03; // 5 bytes address
                        2: spi_tx <= 8'h02; // Channel 2 (Clean)
                        3: spi_tx <= rf_setup_val; 
                        4: spi_tx <= 8'h06; // 6 bytes payload
                    endcase
                    spi_start <= 1;
                    state <= S_WRITE_REGS+2;
                end
                S_WRITE_REGS+2: begin
                    if (!spi_busy) begin csn <= 1; reg_idx <= reg_idx + 1; state <= S_WRITE_REGS; end
                end

                // Address 0xE7E7E7E7E7
                S_WRITE_ADDR: begin
                    if (!spi_busy && addr_idx < 6) begin 
                        if (addr_idx == 0) begin 
                            csn <= 0; 
                            spi_tx <= {CMD_W_REGISTER, REG_RX_ADDR_P0}; 
                            spi_start <= 1; 
                        end
                        else begin 
                            spi_tx <= 8'hE7; 
                            spi_start <= 1; 
                        end
                        addr_idx <= addr_idx + 1;
                    end else if (addr_idx == 6) begin 
                        if (!spi_busy) begin csn <= 1; state <= S_CONFIG_2; end
                    end
                end

                S_CONFIG_2: begin 
                    if (!spi_busy) begin
                        csn <= 0; spi_tx <= {CMD_W_REGISTER, REG_CONFIG}; spi_start <= 1;
                        state <= S_CONFIG_2 + 1;
                    end
                end
                S_CONFIG_2+1: begin
                    if (!spi_busy) begin spi_tx <= 8'h0F; spi_start <= 1; state <= S_CONFIG_2+2; end
                end
                S_CONFIG_2+2: if (!spi_busy) begin csn <= 1; state <= S_RX_MODE; end
                
                S_RX_MODE: begin
                    ce  <= 1; 
                    state <= S_POLL_START;
                end

                // === LOGIC POLLING ?Ã S?A ===
                S_POLL_START: begin
                    if (USE_IRQ) begin
                        // N?u dùng IRQ (ch?a dùng ngay), logic ? ?ây
                    end else begin
                        // G?i l?nh NOP ?? ??c Status
                        if (!spi_busy) begin
                            csn <= 0; 
                            spi_tx <= CMD_NOP; 
                            spi_start <= 1;
                            state <= S_POLL_WAIT;
                        end
                    end
                end
                
                S_POLL_WAIT: begin
                    // ??i Master báo Busy lên 1 r?i v? 0 (Transaction Complete)
                    // Nh?ng spi_master c?a b?n ch? báo busy=1.
                    // Cách ??n gi?n nh?t: ??i !spi_busy và spi_start ?ã t?t.
                    // Logic ? ?ây: spi_start t? t?t ? cycle sau.
                    // Ta ch? c?n ??i !spi_busy là ???c (mi?n là ?ã qua 1 cycle)
                    if (!spi_busy) begin
                        csn <= 1; // K?t thúc l?nh NOP
                        state <= S_POLL_CHECK;
                    end
                end

                S_POLL_CHECK: begin
                    // Ki?m tra bit 6 (RX_DR) c?a giá tr? v?a ??c v? (spi_rx)
                    if (spi_rx[6] == 1'b1) begin
                        state <= S_READ_STATUS; // Có d? li?u -> ?i ??c
                    end else begin
                        state <= S_POLL_START;  // Ch?a có -> Poll l?i
                    end
                end

                S_READ_STATUS: begin
                    if (!spi_busy) begin 
                        csn <= 0; spi_tx <= CMD_R_RX_PAYLOAD; spi_start <= 1; 
                        payload_idx <= 0; 
                        state <= S_READ_PAYLOAD; 
                    end
                end

                S_READ_PAYLOAD: begin
                    if (!spi_busy) begin
                        if (payload_idx > 0) begin  
                            case (payload_idx)
                                1: payload_0 <= spi_rx;
                                2: payload_1 <= spi_rx;
                                3: payload_2 <= spi_rx;
                                4: payload_3 <= spi_rx;
                                5: payload_4 <= spi_rx;
                                6: payload_5 <= spi_rx;
                            endcase
                        end
                        if (payload_idx < 6) begin
                            spi_tx <= 8'h00; spi_start <= 1;
                            payload_idx <= payload_idx + 1;
                        end else begin
                            csn <= 1;
                            state <= S_CLEAR_IRQ;
                        end
                    end
                end

                S_CLEAR_IRQ: begin
                    if (!spi_busy) begin csn <= 0; spi_tx <= {CMD_W_REGISTER, REG_STATUS}; spi_start <= 1; state <= S_CLEAR_IRQ+1; end
                end
                S_CLEAR_IRQ+1: begin
                    if (!spi_busy) begin spi_tx <= 8'h70; spi_start <= 1; state <= S_CLEAR_IRQ+2; end
                end
                S_CLEAR_IRQ+2: if (!spi_busy) begin csn <= 1; state <= S_FLUSH_RX; end

                S_FLUSH_RX: begin
                    if (!spi_busy) begin csn <= 0; spi_tx <= CMD_FLUSH_RX; spi_start <= 1; state <= S_FLUSH_RX+1; end
                end
                S_FLUSH_RX+1: if (!spi_busy) begin csn <= 1; state <= S_DATA_READY; end

                S_DATA_READY: begin
                    if (!spi_busy) begin
                        data_ready <= 1;
                        state <= S_RX_MODE; // Quay v? l?ng nghe
                    end
                end

                default: state <= S_PWR_ON_DELAY;
            endcase
        end
    end
endmodule