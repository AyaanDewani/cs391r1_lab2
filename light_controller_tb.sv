`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/01/2026 10:06:14 PM
// Design Name: 
// Module Name: light_controller_tb
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


module light_controller_tb;
    localparam int CLK_PERIOD = 4;    // ns, so one cycle is 4 ns

    // N values required by the lab:
    //   1  -> a color change every clock cycle
    //   10 -> a color change every 10 clock cycles
    //   25 -> a color change every 100 ns (25 cycles at 4 ns each)
    localparam int N0 = 1;
    localparam int N1 = 10;
    localparam int N2 = 25;

    logic clk = 1'b0;
    logic rst, button;
    logic [2:0] state0, state1, state2;
    int errors = 0;

    always #(CLK_PERIOD/2) clk = ~clk;

    light_controller #(.N(N0)) dut0 (.clk(clk), .rst(rst), .button(button), .light_state(state0));
    light_controller #(.N(N1)) dut1 (.clk(clk), .rst(rst), .button(button), .light_state(state1));
    light_controller #(.N(N2)) dut2 (.clk(clk), .rst(rst), .button(button), .light_state(state2));

    // Reference model: state after c clock cycles of being held down
    function automatic logic [2:0] expected(input int n, input int c);
        int steps;
        steps = c / n;                  // how many color changes have happened
        return 3'd1 + (steps % 7);      // wraps from 7 back to 1
    endfunction

    task automatic compare(input string name, input int n, input logic [2:0] got,
                           input logic [2:0] exp, input int c);
        if (got !== exp) begin
            $error("FAIL: N=%0d cycle=%0d light_state=%0d (expected %0d)", n, c, got, exp);
            errors++;
        end
    endtask

    // Hold the button for the given number of clock cycles, checking every cycle
    task automatic press_and_check(input int cycles);
        @(negedge clk);
        button = 1'b1;
        for (int c = 0; c < cycles; c++) begin
            @(negedge clk);
            compare("N0", N0, state0, expected(N0, c), c);
            compare("N1", N1, state1, expected(N1, c), c);
            compare("N2", N2, state2, expected(N2, c), c);
        end
        @(negedge clk);
        button = 1'b0;
        @(negedge clk);
        // Rule 1: all three must go dark after release
        compare("N0", N0, state0, 3'd0, -1);
        compare("N1", N1, state1, 3'd0, -1);
        compare("N2", N2, state2, 3'd0, -1);
        $display("Press of %0d cycles checked", cycles);
    endtask

    initial begin
        // Reset
        rst = 1'b1; button = 1'b0;
        repeat (2) @(negedge clk);
        if (state0 !== 3'd0 || state1 !== 3'd0 || state2 !== 3'd0) begin
            $error("FAIL: reset did not clear light_state");
            errors++;
        end
        rst = 1'b0;

        // Rule 1: idle with the button up keeps the light off
        repeat (5) @(negedge clk);
        compare("N0", N0, state0, 3'd0, -1);
        compare("N1", N1, state1, 3'd0, -1);
        compare("N2", N2, state2, 3'd0, -1);
        $display("Idle state checked");

        // Long press: 200 cycles is enough for all three to wrap past 7 back to 1
        press_and_check(200);

        // Short press: light turns on at state 1 and goes dark again
        press_and_check(3);

        // Second long press: confirms a new press restarts at 1
        press_and_check(60);

        // Reset while the button is held must force the light off
        @(negedge clk) button = 1'b1;
        repeat (5) @(negedge clk);
        rst = 1'b1;
        @(negedge clk);
        compare("N0", N0, state0, 3'd0, -1);
        compare("N1", N1, state1, 3'd0, -1);
        compare("N2", N2, state2, 3'd0, -1);
        $display("Reset during press checked");
        rst = 1'b0; button = 1'b0;
        @(negedge clk);

        if (errors == 0) $display("All tests passed for N = %0d, %0d, %0d", N0, N1, N2);
        else             $display("%0d test(s) failed", errors);
        $finish;
    end
endmodule
