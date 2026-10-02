`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/01/2026 10:03:04 PM
// Design Name: 
// Module Name: light_controller
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module light_controller #(
    parameter int N = 1       // clock cycles between color changes while held
) (
    input  wire       clk,
    input  wire       rst,
    input  wire       button,
    output reg  [2:0] light_state   // 0 = off, 1 to 7 = colors
);
    reg [31:0] count;      // cycles since the last color change
    reg        button_d;   // button value from the previous clock cycle

    always_ff @(posedge clk) begin
        if (rst) begin
            light_state <= 3'd0;
            count       <= 32'd0;
            button_d    <= 1'b0;
        end else begin
            button_d <= button;

            if (!button) begin
                // Rule 1: button released, light goes dark
                light_state <= 3'd0;
                count       <= 32'd0;
            end else if (!button_d) begin
                // Rule 2: this is the first cycle of a new press
                light_state <= 3'd1;
                count       <= 32'd0;
            end else begin
                // Rule 3: still held, advance every N cycles
                if (count == N - 1) begin
                    count       <= 32'd0;
                    light_state <= (light_state == 3'd7) ? 3'd1 : light_state + 3'd1;
                end else begin
                    count <= count + 32'd1;
                end
            end
        end
    end
endmodule
