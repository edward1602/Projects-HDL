`timescale 1ns / 1ps

module payload_assembler (
    input clk,
    input rst_n,
    
    // Interface from nrf24l01_controller module
    input [7:0] rx_byte_in,        // Input byte from the RX_READ_PAYLOAD_BYTE state
    input [2:0] rx_byte_count_in,  // Byte counter (5 down to 0) from the controller
    input rx_data_valid_in,        // Flag indicating a new, valid byte is present on rx_byte_in

    // Assembled output data (16 bits for each axis, matching Arduino 'int')
    output reg [15:0] x_axis_out,
    output reg [15:0] y_axis_out,
    output reg [15:0] z_axis_out,
    
    // Flag indicating a complete 6-byte packet has been assembled
    output reg packet_ready
);

    // Internal index to map the controller's counter (5->0) to array index (0->5)
    reg [2:0] current_byte_index; 
    
    // Temporary register array (buffer) to hold the 6 incoming bytes
    // Array indices correspond to the byte position in the packet (0 to 5)
    reg [7:0] byte_buffer [0:5]; 

// ----------------------------------------------------
// SEQUENTIAL LOGIC: BYTE STAGING AND ASSEMBLY
// ----------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // --- Reset Logic ---
        current_byte_index <= 3'd0;
        x_axis_out <= 16'h0000;
        y_axis_out <= 16'h0000;
        z_axis_out <= 16'h0000;
        packet_ready <= 1'b0;
        
        // Initialize Buffer
        for (integer i = 0; i < 6; i = i + 1) begin
            byte_buffer[i] <= 8'h00;
        end
    end else begin
        packet_ready <= 1'b0; // Pulse the ready flag for only one clock cycle
        
        // --- 1. Store Incoming Data Byte ---
        if (rx_data_valid_in) begin
            // Convert controller's countdown counter (5, 4, 3, 2, 1, 0) 
            // to a sequential array index (0, 1, 2, 3, 4, 5).
            // Index = 5 - Counter
            current_byte_index <= 3'd5 - rx_byte_count_in; 
            
            // Store the incoming byte into the calculated position in the buffer.
            // Byte 0 (LSB of X) is stored at index 0, Byte 5 (MSB of Z) at index 5.
            byte_buffer[current_byte_index] <= rx_byte_in;
            
            // --- 2. Assemble and Flag Packet Completion ---
            // The last byte is received when the counter reaches 0.
            if (rx_byte_count_in == 3'd0) begin
                
                // Assemble the 16-bit values (Little-Endian format from Arduino):
                // X Axis: Byte 1 (MSB) concatenated with Byte 0 (LSB)
                x_axis_out <= {byte_buffer[1], byte_buffer[0]};
                
                // Y Axis: Byte 3 (MSB) concatenated with Byte 2 (LSB)
                y_axis_out <= {byte_buffer[3], byte_buffer[2]};
                
                // Z Axis: Byte 5 (MSB) concatenated with Byte 4 (LSB)
                z_axis_out <= {byte_buffer[5], byte_buffer[4]};
                
                packet_ready <= 1'b1; // The assembled packet is ready
                
                // Reset internal state for the next incoming packet
                for (integer i = 0; i < 6; i = i + 1) begin
                    byte_buffer[i] <= 8'h00;
                end
                current_byte_index <= 3'd0;
            end
        end
    end
end

endmodule