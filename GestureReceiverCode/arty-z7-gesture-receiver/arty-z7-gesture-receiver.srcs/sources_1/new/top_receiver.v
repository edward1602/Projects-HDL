`timescale 1ns / 1ps

module arty_nrf_receiver_top (
    // Clock và Reset H? th?ng
    input clk_100mhz,
    input rst_n,          
    
    // Giao di?n V?t lý nRF24L01
    output nrf_ce_pin,    
    output nrf_csn_pin,   
    output nrf_sck_pin,   
    output nrf_mosi_pin,  
    input nrf_miso_pin,   
    input nrf_irq_pin,    
    
    // ??U RA D? LI?U ?Ã X? LÝ (?? b?n truy c?p)
    output [15:0] x_axis_data_out,
    output [15:0] y_axis_data_out,
    output [15:0] z_axis_data_out,
    output led_rdy       // Báo hi?u gói tin ?ã s?n sàng
);

// ----------------------------------------------------
// KHAI BÁO TÍN HI?U N?I B? (reg/wire)
// ----------------------------------------------------

    // Tín hi?u ?i?u khi?n nrf24l01_controller
    reg cmd_start;
    wire cmd_done;
    wire [7:0] status_reg_out;

    // Tín hi?u D? li?u thô t? nrf24l01_controller
    wire [7:0] data_byte_from_nrf;
    wire data_valid_flag;
    wire [2:0] byte_counter;

    // Tín hi?u D? li?u ?ã x? lý t? payload_assembler
    wire [15:0] x_out, y_out, z_out;
    wire packet_ready_flag;

    // Gán tr?c ti?p chân v?t lý (wire)
    wire nrf_ce_i, nrf_csn_i, nrf_sck_i, nrf_mosi_i;
    assign nrf_ce_pin = nrf_ce_i;
    assign nrf_csn_pin = nrf_csn_i;
    assign nrf_sck_pin = nrf_sck_i;
    assign nrf_mosi_pin = nrf_mosi_i;

    // Gán ??u ra d? li?u và LED
    assign x_axis_data_out = x_out;
    assign y_axis_data_out = y_out;
    assign z_axis_data_out = z_out;
    assign led_rdy = packet_ready_flag;


// ----------------------------------------------------
// 1. Th? hi?n NRF24L01 CONTROLLER
// ----------------------------------------------------
    nrf24l01_controller nrf_ctrl_inst (
        .clk(clk_100mhz),
        .rst_n(rst_n),
        
        // Command Interface
        .cmd_start(cmd_start),
        .cmd_done(cmd_done),
        
        // Physical nRF24L01 Pins (K?t n?i v?i wire trung gian)
        .nrf_ce(nrf_ce_i),
        .nrf_csn(nrf_csn_i),
        .nrf_irq(nrf_irq_pin),
        .status_reg_out(status_reg_out),
        
        // SPI Interface (K?t n?i v?i wire trung gian)
        .spi_sck(nrf_sck_i),
        .spi_mosi(nrf_mosi_i),
        .spi_miso(nrf_miso_pin),
        
        // Raw Data Output
        .rx_byte_out(data_byte_from_nrf), 
        .rx_byte_count(byte_counter), 
        .rx_data_valid(data_valid_flag) 
    );

// ----------------------------------------------------
// 2. Th? hi?n PAYLOAD ASSEMBLER
// ----------------------------------------------------
    payload_assembler assembler_inst (
        .clk(clk_100mhz),
        .rst_n(rst_n),
        
        // Input from nrf24l01_controller
        .rx_byte_in(data_byte_from_nrf), 
        .rx_byte_count_in(byte_counter),
        .rx_data_valid_in(data_valid_flag),
        
        // Assembled Data Output
        .x_axis_out(x_out),
        .y_axis_out(y_out),
        .z_axis_out(z_out),
        .packet_ready(packet_ready_flag)
    );

// ----------------------------------------------------
// 3. LOGIC ?I?U KHI?N KH?I T?O (CH? C?N 1 XUNG)
// ----------------------------------------------------
    reg init_sent_reg;

    always @(posedge clk_100mhz or negedge rst_n) begin
        if (!rst_n) begin
            cmd_start <= 1'b0;
            init_sent_reg <= 1'b0;
        end else begin
            // Kích ho?t Kh?i t?o ? chu k? ??u tiên sau khi thoát Reset
            if (!init_sent_reg) begin
                cmd_start <= 1'b1;
                init_sent_reg <= 1'b1;
            end else begin
                // Gi? cmd_start th?p sau khi nó ?ã ???c kích ho?t
                cmd_start <= 1'b0;
            end
        end
    end
    
endmodule