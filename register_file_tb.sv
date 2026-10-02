`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/02/2026 10:33:08 AM
// Design Name: 
// Module Name: register_file_tb
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



module register_file_tb;
    localparam int WIDTH      = 32;
    localparam int NUM_REGS   = 16;
    localparam int ADDR_WIDTH = $clog2(NUM_REGS);
    localparam int CLK_PERIOD = 10;
 
    logic clk = 1'b0;
    logic rst, we;
    logic [ADDR_WIDTH-1:0] rd_sel, rs_sel, rt_sel;
    logic [WIDTH-1:0]      d_in, rs, rt;
    int errors = 0;
 
    // Reference model: what each register should contain
    logic [WIDTH-1:0] model [0:NUM_REGS-1];
 
    always #(CLK_PERIOD/2) clk = ~clk;
 
    register_file #(.WIDTH(WIDTH), .NUM_REGS(NUM_REGS)) dut (
        .clk(clk), .rst(rst), .we(we), .rd_sel(rd_sel), .d_in(d_in),
        .rs_sel(rs_sel), .rs(rs), .rt_sel(rt_sel), .rt(rt)
    );
 
    // Write value v into register a on the next clock edge
    task automatic write_reg(input logic [ADDR_WIDTH-1:0] a, input logic [WIDTH-1:0] v);
        @(negedge clk);
        we = 1'b1; rd_sel = a; d_in = v;
        @(negedge clk);
        we = 1'b0;
        model[a] = v;
    endtask
 
    // Point both read ports at registers a and b and check them
    task automatic read_check(input logic [ADDR_WIDTH-1:0] a, input logic [ADDR_WIDTH-1:0] b);
        rs_sel = a; rt_sel = b;
        #1;   // combinational reads settle immediately
        if (rs !== model[a]) begin
            $error("FAIL: rs read of reg %0d gave %h (expected %h)", a, rs, model[a]);
            errors++;
        end
        if (rt !== model[b]) begin
            $error("FAIL: rt read of reg %0d gave %h (expected %h)", b, rt, model[b]);
            errors++;
        end
    endtask
 
    logic [WIDTH-1:0] v;
 
    initial begin
        we = 1'b0; rd_sel = '0; rs_sel = '0; rt_sel = '0; d_in = '0;
 
        // Reset clears every register 
        rst = 1'b1;
        repeat (2) @(negedge clk);
        rst = 1'b0;
        for (int i = 0; i < NUM_REGS; i++) model[i] = '0;
        for (int i = 0; i < NUM_REGS; i++) read_check(i[ADDR_WIDTH-1:0], i[ADDR_WIDTH-1:0]);
        $display("Reset check done");
 
        //  Write a distinct value to every register, then read them all back 
        for (int i = 0; i < NUM_REGS; i++)
            write_reg(i[ADDR_WIDTH-1:0], 32'hA5A5_0000 + i);
        for (int i = 0; i < NUM_REGS; i++)
            read_check(i[ADDR_WIDTH-1:0], (NUM_REGS - 1 - i));
        $display("Write then read back all %0d registers done", NUM_REGS);
 
        //  Both read ports can read different registers at the same time 
        read_check(4'd3, 4'd12);
        // ---- Both read ports can read the SAME register at the same time ----
        read_check(4'd7, 4'd7);
        $display("Dual read port checks done");
 
        // ---- we = 0 must not change anything ----
        @(negedge clk);
        we = 1'b0; rd_sel = 4'd5; d_in = 32'hDEAD_BEEF;
        @(negedge clk);
        read_check(4'd5, 4'd5);
        $display("Write disable check done");
 
        // Overwriting a register 
        write_reg(4'd9, 32'h1234_5678);
        read_check(4'd9, 4'd9);
        write_reg(4'd9, 32'h8765_4321);
        read_check(4'd9, 4'd9);
        $display("Overwrite check done");
 
        // **** Reading a register while it is being written returns the OLD value until the clock edge, then the new one 
        @(negedge clk);
        we = 1'b1; rd_sel = 4'd2; d_in = 32'hFFFF_0001;
        rs_sel = 4'd2;
        #1;
        if (rs !== model[2]) begin
            $error("FAIL: read during write gave %h (expected old value %h)", rs, model[2]);
            errors++;
        end
        @(negedge clk);
        we = 1'b0;
        model[2] = 32'hFFFF_0001;
        read_check(4'd2, 4'd2);
        $display("Read during write check done");
 
        // Random writes and reads
        repeat (50) begin
            v = $urandom;
            write_reg($urandom_range(NUM_REGS-1, 0), v);
            read_check($urandom_range(NUM_REGS-1, 0), $urandom_range(NUM_REGS-1, 0));
        end
        $display("Random write and read checks done");
 
        // Reset again clears everything, even after writes 
        @(negedge clk);
        rst = 1'b1;
        @(negedge clk);
        rst = 1'b0;
        for (int i = 0; i < NUM_REGS; i++) model[i] = '0;
        for (int i = 0; i < NUM_REGS; i++) read_check(i[ADDR_WIDTH-1:0], i[ADDR_WIDTH-1:0]);
        $display("Second reset check done");
 
        if (errors == 0) $display("All tests passed for WIDTH = %0d, NUM_REGS = %0d", WIDTH, NUM_REGS);
        else             $display("%0d test(s) failed", errors);
        $finish;
    end
endmodule
