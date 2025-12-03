`timescale 1ns / 1ps

module tb_nrf24l01_rx_controller;

    localparam CLK_PERIOD = 8;
    localparam [47:0] EXPECTED_PAYLOAD = 48'h9ABC56781234;

    reg clk;
    reg rst_n;
    reg start_rx;
    wire rx_ready;
    wire nrf_ce;
    wire nrf_csn;
    reg nrf_irq;
    wire spi_sck;
    wire spi_mosi;
    reg spi_miso;
    wire [47:0] rx_payload;
    wire payload_ready;

    nrf24l01_simple_rx_controller #(
        .USE_IRQ(1),
        .RX_POLL_INTERVAL(24'd64),
        .INITIAL_DELAY_COUNT(27'd16),
        .POWERUP_DELAY_COUNT(27'd16)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start_rx(start_rx),
        .rx_ready(rx_ready),
        .nrf_ce(nrf_ce),
        .nrf_csn(nrf_csn),
        .nrf_irq(nrf_irq),
        .spi_sck(spi_sck),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .rx_payload(rx_payload),
        .payload_ready(payload_ready)
    );

    initial clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    initial begin
        rst_n = 1'b0;
        start_rx = 1'b0;
        nrf_irq = 1'b1;
        spi_miso = 1'b0;

        #(10 * CLK_PERIOD);
        rst_n = 1'b1;

        repeat (5) @(posedge clk);
        start_rx = 1'b1;
        @(posedge clk);
        start_rx = 1'b0;

        wait (rx_ready == 1'b1);
        $display("[%0t] RX ready asserted", $time);

        repeat (200) @(posedge clk);
        inject_payload(EXPECTED_PAYLOAD);
        nrf_irq = 1'b0;
        $display("[%0t] IRQ asserted with payload", $time);

        wait (payload_ready == 1'b1);
        $display("[%0t] payload_ready pulse detected", $time);
        nrf_irq = 1'b1;

        wait (status_reg[6] == 1'b0);
        $display("[%0t] status RX_DR cleared", $time);

        repeat (100) @(posedge clk);
        $display("[%0t] Test completed", $time);
        $finish;
    end

    initial begin
        #(2_000_000);
        $fatal(1, "Timeout waiting for payload reception");
    end

    localparam [4:0] REG_STATUS = 5'h07;
    localparam [4:0] REG_RX_ADDR_P0 = 5'h0A;
    localparam [4:0] REG_RX_PW_P0 = 5'h11;
    localparam [4:0] REG_FIFO_STATUS = 5'h17;

    reg [7:0] status_reg;
    reg [7:0] fifo_status_reg;
    reg [7:0] regfile [0:31];
    reg [7:0] pipe0_addr [0:4];
    reg [7:0] payload_mem [0:5];

    localparam integer PAYLOAD_LEN = 6;

    reg [7:0] miso_shift;
    reg [7:0] mosi_shift;
    reg [7:0] current_cmd;
    reg is_write;
    reg is_read;
    reg expect_toggle;
    reg payload_read;
    integer pending_write_bytes;
    integer pending_read_bytes;
    reg [2:0] write_index;
    reg [2:0] read_index;
    reg [2:0] payload_index;
    integer bit_count;

    initial begin
        integer i;
        status_reg = 8'h0E;
        fifo_status_reg = 8'h01;
        miso_shift = 8'h0E;
        mosi_shift = 8'h00;
        current_cmd = 8'h00;
        is_write = 1'b0;
        is_read = 1'b0;
        expect_toggle = 1'b0;
        payload_read = 1'b0;
        pending_write_bytes = 0;
        pending_read_bytes = 0;
        write_index = 3'd0;
        read_index = 3'd0;
        payload_index = 3'd0;
        bit_count = 0;
        for (i = 0; i < 32; i = i + 1)
            regfile[i] = 8'h00;
        for (i = 0; i < 5; i = i + 1)
            pipe0_addr[i] = 8'h00;
        for (i = 0; i < 6; i = i + 1)
            payload_mem[i] = 8'h00;
        update_status();
        update_fifo();
    end

    task automatic update_status;
        begin
            regfile[REG_STATUS] = status_reg;
        end
    endtask

    task automatic update_fifo;
        begin
            regfile[REG_FIFO_STATUS] = fifo_status_reg;
        end
    endtask

    task automatic inject_payload(input [47:0] payload_word);
        begin
            payload_mem[0] = payload_word[7:0];
            payload_mem[1] = payload_word[15:8];
            payload_mem[2] = payload_word[23:16];
            payload_mem[3] = payload_word[31:24];
            payload_mem[4] = payload_word[39:32];
            payload_mem[5] = payload_word[47:40];
            payload_index = 3'd0;
            payload_read = 1'b0;
            status_reg[6] = 1'b1;
            update_status();
            fifo_status_reg[0] = 1'b0;
            update_fifo();
        end
    endtask

    function automatic [7:0] read_register_byte(input [4:0] addr, input [2:0] index);
        begin
            case (addr)
                REG_RX_ADDR_P0: read_register_byte = pipe0_addr[index];
                REG_FIFO_STATUS: read_register_byte = fifo_status_reg;
                REG_STATUS: read_register_byte = status_reg;
                default: read_register_byte = regfile[addr];
            endcase
        end
    endfunction

    task automatic write_register_byte(input [4:0] addr, input [2:0] index, input [7:0] value);
        begin
            case (addr)
                REG_STATUS: begin
                    status_reg[6:4] = status_reg[6:4] & ~value[6:4];
                    update_status();
                end
                REG_RX_ADDR_P0: begin
                    pipe0_addr[index] = value;
                    if (index == 3'd0)
                        regfile[REG_RX_ADDR_P0] = value;
                end
                REG_RX_PW_P0: regfile[REG_RX_PW_P0] = value;
                default: regfile[addr] = value;
            endcase
        end
    endtask

    always @(negedge nrf_csn) begin
        miso_shift <= status_reg;
        spi_miso <= status_reg[7];
        mosi_shift <= 8'h00;
        current_cmd <= 8'h00;
        is_write <= 1'b0;
        is_read <= 1'b0;
        expect_toggle <= 1'b0;
        payload_read <= 1'b0;
        pending_write_bytes <= 0;
        pending_read_bytes <= 0;
        write_index <= 3'd0;
        read_index <= 3'd0;
        bit_count <= 0;
    end

    always @(posedge nrf_csn) begin
        spi_miso <= 1'b0;
        miso_shift <= status_reg;
        is_write <= 1'b0;
        is_read <= 1'b0;
        expect_toggle <= 1'b0;
        payload_read <= 1'b0;
        pending_write_bytes <= 0;
        pending_read_bytes <= 0;
        write_index <= 3'd0;
        read_index <= 3'd0;
        bit_count <= 0;
    end

    always @(negedge spi_sck) begin
        if (!nrf_csn) begin
            spi_miso <= miso_shift[7];
            miso_shift <= {miso_shift[6:0], 1'b0};
        end
    end

    always @(posedge spi_sck) begin
        if (!nrf_csn) begin
            mosi_shift <= {mosi_shift[6:0], spi_mosi};
            if (bit_count == 7) begin
                bit_count <= 0;
                process_byte({mosi_shift[6:0], spi_mosi});
            end else begin
                bit_count <= bit_count + 1;
            end
        end
    end

    task automatic process_byte(input [7:0] value);
        begin
            if (current_cmd == 8'h00 && !is_write && !is_read && !expect_toggle && !payload_read) begin
                current_cmd <= value;
                if ((value & 8'hE0) == 8'h20) begin
                    is_write <= 1'b1;
                    write_index <= 3'd0;
                    pending_write_bytes = (value[4:0] == REG_RX_ADDR_P0) ? 5 : 1;
                    miso_shift <= status_reg;
                end else if ((value & 8'hE0) == 8'h00) begin
                    is_read <= 1'b1;
                    read_index <= 3'd0;
                    pending_read_bytes = (value[4:0] == REG_RX_ADDR_P0) ? 5 : 1;
                    miso_shift <= read_register_byte(value[4:0], 3'd0);
                end else begin
                    case (value)
                        8'h50: begin
                            expect_toggle <= 1'b1;
                            miso_shift <= status_reg;
                        end
                        8'h61: begin
                            payload_read <= 1'b1;
                            payload_index <= 3'd0;
                            miso_shift <= payload_mem[0];
                        end
                        8'hE1: miso_shift <= status_reg;
                        8'hE2: begin
                            miso_shift <= status_reg;
                            fifo_status_reg[0] = 1'b1;
                            update_fifo();
                        end
                        default: miso_shift <= status_reg;
                    endcase
                end
            end else if (expect_toggle) begin
                expect_toggle <= 1'b0;
                miso_shift <= status_reg;
            end else if (is_write) begin
                write_register_byte(current_cmd[4:0], write_index, value);
                write_index = write_index + 1;
                pending_write_bytes = pending_write_bytes - 1;
                if (pending_write_bytes == 0)
                    is_write <= 1'b0;
                miso_shift <= status_reg;
            end else if (is_read) begin
                pending_read_bytes = pending_read_bytes - 1;
                read_index = read_index + 1;
                if (pending_read_bytes == 0) begin
                    miso_shift <= status_reg;
                    is_read <= 1'b0;
                end else begin
                    miso_shift <= read_register_byte(current_cmd[4:0], read_index);
                end
            end else if (payload_read) begin
                payload_index = payload_index + 1;
                if (payload_index == PAYLOAD_LEN) begin
                    payload_read <= 1'b0;
                    fifo_status_reg[0] = 1'b1;
                    update_fifo();
                    miso_shift <= status_reg;
                end else begin
                    miso_shift <= payload_mem[payload_index];
                end
            end else begin
                miso_shift <= status_reg;
            end
        end
    endtask

    always @(posedge payload_ready) begin
        $display("[%0t] payload captured: 0x%012h", $time, rx_payload);
        if (rx_payload !== EXPECTED_PAYLOAD) begin
            $fatal(1, "Payload mismatch. Expected 0x%012h, got 0x%012h", EXPECTED_PAYLOAD, rx_payload);
        end else begin
            $display("[%0t] Payload matches expected data", $time);
        end
    end

endmodule