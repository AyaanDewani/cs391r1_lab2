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

`timescale 1ns / 1ps

module light_controller_tb;
    // Target hardware: 100 MHz clock, so one cycle is 10 ns
    localparam int CLK_HZ      = 100_000_000;
    localparam int CLK_PERIOD  = 10;                  // ns
    localparam int N_REAL      = 3 * CLK_HZ;          // 300,000,000 cycles = 3 s

    // scale down
    localparam int SCALE       = 10;
    localparam int N_SIM       = N_REAL / SCALE;
    localparam int CHANGES     = 2;                   // color changes to verify

    logic clk = 1'b0;
    logic rst, button;
    logic [2:0] light_state;
    int errors = 0;
    realtime t_change, t_prev;

    always #(CLK_PERIOD/2) clk = ~clk;

    light_controller #(.N(N_SIM)) dut (
        .clk(clk), .rst(rst), .button(button), .light_state(light_state)
    );

    task automatic expect_state(input logic [2:0] exp, input string what);
        if (light_state !== exp) begin
            $error("FAIL: %s: light_state=%0d (expected %0d) at %0t", what, light_state, exp, $realtime);
            errors++;
        end else
            $display("PASS: %s: light_state=%0d at %0t", what, light_state, $realtime);
    endtask

    initial begin
        $display("N for a 3 second change at %0d Hz = %0d cycles", CLK_HZ, N_REAL);
        $display("Simulating scaled down by %0d: N = %0d cycles (%0t per change)",
                 SCALE, N_SIM, N_SIM * CLK_PERIOD * 1.0);

        rst = 1'b1; button = 1'b0;
        repeat (2) @(negedge clk);
        rst = 1'b0;
        @(negedge clk);
        expect_state(3'd0, "idle with button up");

        // Press and hold
        @(negedge clk);
        button = 1'b1;
        @(negedge clk);                 // first cycle of the press
        expect_state(3'd1, "first cycle of press");
        t_prev = $realtime;

        for (int k = 1; k <= CHANGES; k++) begin
            // One cycle before the boundary the color must NOT have changed yet
            repeat (N_SIM - 1) @(negedge clk);
            expect_state(3'd0 + k, $sformatf("one cycle before change %0d", k));

            // On the boundary cycle it must advance
            @(negedge clk);
            expect_state(3'd1 + k, $sformatf("at change %0d", k));

            t_change = $realtime;
            if ((t_change - t_prev) != N_SIM * CLK_PERIOD) begin
                $error("FAIL: change %0d took %0t (expected %0t)",
                       k, t_change - t_prev, N_SIM * CLK_PERIOD * 1.0);
                errors++;
            end else
                $display("PASS: change %0d came exactly %0t after the previous one",
                         k, t_change - t_prev);
            t_prev = t_change;
        end

        // Release: light goes dark
        @(negedge clk);
        button = 1'b0;
        @(negedge clk);
        expect_state(3'd0, "after release");

        if (errors == 0) $display("All tests passed. N for 3 s on hardware = %0d", N_REAL);
        else             $display("%0d test(s) failed", errors);
        $finish;
    end
endmodule
