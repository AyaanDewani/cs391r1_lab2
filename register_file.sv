`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/02/2026 10:29:41 AM
// Design Name: 
// Module Name: register_file
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

module register_file #(
    parameter int WIDTH      = 32,                 // bits per register
    parameter int NUM_REGS   = 16,                 
    parameter int ADDR_WIDTH = $clog2(NUM_REGS)    // bits needed to select one
) (
    input  wire                  clk,
    input  wire                  rst,
    
    input  wire                  we,       // write enable
    input  wire [ADDR_WIDTH-1:0] rd_sel,   // destination register
    input  wire [WIDTH-1:0]      d_in,     // data to write
    // Read channel 1
    input  wire [ADDR_WIDTH-1:0] rs_sel,
    output wire [WIDTH-1:0]      rs,
    // Read channel 2
    input  wire [ADDR_WIDTH-1:0] rt_sel,
    output wire [WIDTH-1:0]      rt,
    // Every register exposed flat, for testing only
    output wire [NUM_REGS*WIDTH-1:0] regs_flat
);
    //The storage
    reg [WIDTH-1:0] the_regs [0:NUM_REGS-1];
 
    // Reads are combinational
    assign rs = the_regs[rs_sel];
    assign rt = the_regs[rt_sel];
 
    // Flatten all registers onto one bus so a testbench can watch them
    genvar g;
    generate
        for (g = 0; g < NUM_REGS; g++) begin : gen_expose
            assign regs_flat[g*WIDTH +: WIDTH] = the_regs[g];
        end
    endgenerate
 
    // Writes are synchronous: only on a rising clock edge, and only when we is high
    integer i;
    always_ff @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < NUM_REGS; i = i + 1)
                the_regs[i] <= {WIDTH{1'b0}};
        end else if (we) begin
            the_regs[rd_sel] <= d_in;
        end
    end
endmodule
