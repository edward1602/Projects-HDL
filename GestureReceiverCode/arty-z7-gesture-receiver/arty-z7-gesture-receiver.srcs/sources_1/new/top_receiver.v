`timescale 1ns / 1ps

module top(
    input  wire        clk,            // Clock h? th?ng (50MHz/100MHz)
    input  wire        rst_n,          // Reset (Nút nh?n trên board)

    // --- CÁC CHÂN N?I RA NGOÀI (N?i v?i module nRF24L01 th?t) ---
    input  wire        nrf_miso,       // MISO (Chân này c?n c?m ?úng)
    input  wire        nrf_irq_n,      // IRQ (Chân báo ng?t)
    output wire        nrf_mosi,       // MOSI
    output wire        nrf_sck,        // SCK
    output wire        nrf_csn,        // CSN (Chip Select)
    output wire        nrf_ce,         // CE (Chip Enable)

    // --- OUTPUT CHO NG??I DÙNG (Ví d? n?i ra LED ho?c UART ?? xem) ---
    output wire [47:0] data_received,  // 6 byte d? li?u nh?n ???c
    output wire        data_valid      // ?èn báo khi nh?n xong
);

    // --- 1. KHAI BÁO CÁC DÂY N?I TRONG (INTERNAL WIRES) ---
    // ?ây là các dây "?o" ?? n?i gi?a Controller và SPI Master
    wire        w_spi_start;
    wire        w_spi_done;
    wire [7:0]  w_data_to_spi;   // Controller g?i ?i -> SPI Master
    wire [7:0]  w_data_from_spi; // SPI Master nh?n v? -> Controller
    wire        w_spi_busy;

    // --- 2. NHÚNG MODULE SPI MASTER (Instance) ---
    // Tên module g?c  |  Tên ??t cho instance này
    spi_master #(
        .PRESCALER(50)  // Ch?nh t?c ?? SPI t?i ?ây
    ) u_spi_driver (
        // Bên trái: Tên chân trong module con  |  Bên ph?i: Tên dây n?i ? module Top
        .clk        (clk),
        .rst_n      (rst_n),
        
        // Giao ti?p v?i Controller
        .start      (w_spi_start),      // N?i v?i dây start t? Controller
        .data_in    (w_data_to_spi),    // N?i v?i dây data TX t? Controller
        .data_out   (w_data_from_spi),  // N?i v?i dây data RX v? Controller
        .done       (w_spi_done),       // N?i v?i dây done v? Controller
        .busy       (w_spi_busy),
        
        // Giao ti?p ra chân v?t lý (Port c?a module Top)
        .miso       (nrf_miso),
        .mosi       (nrf_mosi),
        .sck        (nrf_sck)
    );

    // --- 3. NHÚNG MODULE CONTROLLER (Instance) ---
    nrf24l01_controller u_nrf_logic (
        .clk           (clk),
        .rst_n         (rst_n),

        // Giao ti?p v?i SPI Master (Qua các dây internal wires)
        .spi_start     (w_spi_start),     // Output ra dây w_spi_start
        .spi_data_tx   (w_data_to_spi),   // Output ra dây w_data_to_spi
        .spi_data_rx   (w_data_from_spi), // Input t? dây w_data_from_spi
        .spi_done      (w_spi_done),      // Input t? dây w_spi_done

        // Giao ti?p ra chân v?t lý
        .nrf_irq_n     (nrf_irq_n),
        .nrf_csn       (nrf_csn),
        .nrf_ce        (nrf_ce),

        // Output k?t qu?
        .payload_out   (data_received),
        .payload_valid (data_valid)
    );
endmodule