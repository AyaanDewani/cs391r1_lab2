`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/02/2026 02:32:35 PM
// Design Name: 
// Module Name: control_unit_tb
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



module control_unit_tb;
    localparam int WIDTH      = 32;
    localparam int NUM_REGS   = 16;
    localparam int CLK_PERIOD = 10;
 
    // Opcodes from the ISA tables
    localparam logic [5:0] OP_AND  = 6'b000000, OP_ANDI  = 6'b100000;
    localparam logic [5:0] OP_OR   = 6'b000001, OP_ORI   = 6'b100001;
    localparam logic [5:0] OP_XOR  = 6'b000010, OP_XORI  = 6'b100010;
    localparam logic [5:0] OP_XNOR = 6'b000011, OP_XNORI = 6'b100011;
    localparam logic [5:0] OP_SLL  = 6'b000100, OP_SLLI  = 6'b100100;
    localparam logic [5:0] OP_SRL  = 6'b000101, OP_SRLI  = 6'b100101;
    localparam logic [5:0] OP_SLA  = 6'b000110, OP_SLAI  = 6'b100110;
    localparam logic [5:0] OP_SRA  = 6'b000111, OP_SRAI  = 6'b100111;
    localparam logic [5:0] OP_ADD  = 6'b001000, OP_ADDI  = 6'b101000;
    localparam logic [5:0] OP_SUB  = 6'b001001, OP_SUBI  = 6'b101001;
    localparam logic [5:0] OP_LT   = 6'b001010, OP_LTI   = 6'b101010;
    localparam logic [5:0] OP_EQ   = 6'b001011, OP_EQI   = 6'b101011;
    localparam logic [5:0] OP_GT   = 6'b001100, OP_GTI   = 6'b101100;
 
    logic clk = 1'b0;
    logic rst, valid;
    logic [31:0] instruction;
    logic ready, error;
    logic [NUM_REGS*WIDTH-1:0] regs_flat;
    int errors = 0;
 
    // Reference model of the register file
    logic [WIDTH-1:0] model [0:NUM_REGS-1];
 
    always #(CLK_PERIOD/2) clk = ~clk;
 
    control_unit #(.WIDTH(WIDTH), .NUM_REGS(NUM_REGS)) dut (
        .clk(clk), .rst(rst), .instruction(instruction), .valid(valid),
        .ready(ready), .error(error), .regs_flat(regs_flat)
    );
 
    // Pull one register out of the flattened bus
    function automatic logic [WIDTH-1:0] reg_val(input int i);
        return regs_flat[i*WIDTH +: WIDTH];
    endfunction
 
    // Instruction builders
    function automatic logic [31:0] typeA(input logic [5:0] opc,
                                          input logic [3:0] op1, op2, op3);
        return {14'd0, op3, op2, op1, opc};
    endfunction
 
    function automatic logic [31:0] typeB(input logic [5:0] opc,
                                          input logic [3:0] op1, op2,
                                          input logic [17:0] imm);
        return {imm, op2, op1, opc};
    endfunction
 
    // Hand an instruction to the control unit using the valid/ready handshake
    task automatic issue(input logic [31:0] instr);
        // Wait until the control unit is available
        while (!ready) @(negedge clk);
        valid       = 1'b1;
        instruction = instr;
        @(negedge clk);
        valid       = 1'b0;            // not required to hold valid after acceptance
        instruction = 32'hXXXX_XXXX;   // nor the instruction itself
        while (!ready) @(negedge clk); // wait for execution to finish
    endtask
 
    // Check every register against the model, plus the error flag
    task automatic check_all(input string what, input logic exp_err);
        if (error !== exp_err) begin
            $error("FAIL: %s: error=%b (expected %b)", what, error, exp_err);
            errors++;
        end
        for (int i = 0; i < NUM_REGS; i++) begin
            if (reg_val(i) !== model[i]) begin
                $error("FAIL: %s: r%0d = %h (expected %h)", what, i, reg_val(i), model[i]);
                errors++;
            end
        end
    endtask
 
    // Run a Type A instruction and check the result against an expected value
    task automatic run_A(input logic [5:0] opc, input logic [3:0] d, a, b,
                         input logic [WIDTH-1:0] exp, input string name);
        issue(typeA(opc, d, a, b));
        model[d] = exp;
        check_all(name, 1'b0);
        $display("PASS: %s -> r%0d = %h", name, d, reg_val(d));
    endtask
 
    task automatic run_B(input logic [5:0] opc, input logic [3:0] d, a,
                         input logic [17:0] imm,
                         input logic [WIDTH-1:0] exp, input string name);
        issue(typeB(opc, d, a, imm));
        model[d] = exp;
        check_all(name, 1'b0);
        $display("PASS: %s -> r%0d = %h", name, d, reg_val(d));
    endtask
 
    // Load a constant into a register: OR of r0 (always 0 after reset) with an immediate
    task automatic load_imm(input logic [3:0] d, input logic [17:0] imm);
        run_B(OP_ORI, d, 4'd0, imm, {14'd0, imm}, $sformatf("ORI r%0d, r0, %h", d, imm));
    endtask
 
    logic [WIDTH-1:0] a_val, b_val;
 
    initial begin
        valid = 1'b0; instruction = 32'd0;
 
        // Reset 
        rst = 1'b1;
        repeat (2) @(negedge clk);
        rst = 1'b0;
        @(negedge clk);
        for (int i = 0; i < NUM_REGS; i++) model[i] = '0;
        check_all("after reset", 1'b0);
        if (ready !== 1'b1) begin
            $error("FAIL: ready should be high after reset");
            errors++;
        end
        $display("Reset and ready check done");
 
        // Load constants with Type B 
        load_imm(4'd1, 18'h0_00F0);
        load_imm(4'd2, 18'h0_000C);
        load_imm(4'd3, 18'h3_FFFF);
        a_val = model[1];
        b_val = model[2];
        $display("Immediate loads done");
 
        // Type A: every operation 
        run_A(OP_AND,  4'd4, 4'd1, 4'd2, a_val & b_val,            "AND  r4, r1, r2");
        run_A(OP_OR,   4'd4, 4'd1, 4'd2, a_val | b_val,            "OR   r4, r1, r2");
        run_A(OP_XOR,  4'd4, 4'd1, 4'd2, a_val ^ b_val,            "XOR  r4, r1, r2");
        run_A(OP_XNOR, 4'd4, 4'd1, 4'd2, ~(a_val ^ b_val),         "XNOR r4, r1, r2");
        run_A(OP_SLL,  4'd5, 4'd1, 4'd2, a_val << b_val,           "SLL  r5, r1, r2");
        run_A(OP_SRL,  4'd5, 4'd1, 4'd2, a_val >> b_val,           "SRL  r5, r1, r2");
        run_A(OP_SLA,  4'd5, 4'd1, 4'd2, a_val << b_val,           "SLA  r5, r1, r2");
        run_A(OP_SRA,  4'd5, 4'd3, 4'd2, $signed(model[3]) >>> b_val, "SRA  r5, r3, r2");
        run_A(OP_ADD,  4'd6, 4'd1, 4'd2, a_val + b_val,            "ADD  r6, r1, r2");
        run_A(OP_SUB,  4'd6, 4'd1, 4'd2, a_val - b_val,            "SUB  r6, r1, r2");
        run_A(OP_LT,   4'd7, 4'd1, 4'd2, {31'd0, a_val <  b_val},  "LT   r7, r1, r2");
        run_A(OP_EQ,   4'd7, 4'd1, 4'd2, {31'd0, a_val == b_val},  "EQ   r7, r1, r2");
        run_A(OP_GT,   4'd7, 4'd1, 4'd2, {31'd0, a_val >  b_val},  "GT   r7, r1, r2");
        $display("All Type A instructions done");
 
        // Type B: every operation 
        run_B(OP_ANDI,  4'd8, 4'd1, 18'h0_00FF, a_val & 32'h0000_00FF,     "ANDI  r8, r1, 0ff");
        run_B(OP_ORI,   4'd8, 4'd1, 18'h0_0F00, a_val | 32'h0000_0F00,     "ORI   r8, r1, f00");
        run_B(OP_XORI,  4'd8, 4'd1, 18'h0_00FF, a_val ^ 32'h0000_00FF,     "XORI  r8, r1, 0ff");
        run_B(OP_XNORI, 4'd8, 4'd1, 18'h0_00FF, ~(a_val ^ 32'h0000_00FF),  "XNORI r8, r1, 0ff");
        run_B(OP_SLLI,  4'd9, 4'd1, 18'd4,      a_val << 4,                "SLLI  r9, r1, 4");
        run_B(OP_SRLI,  4'd9, 4'd1, 18'd4,      a_val >> 4,                "SRLI  r9, r1, 4");
        run_B(OP_SLAI,  4'd9, 4'd1, 18'd4,      a_val << 4,                "SLAI  r9, r1, 4");
        run_B(OP_SRAI,  4'd9, 4'd3, 18'd4,      $signed(model[3]) >>> 4,   "SRAI  r9, r3, 4");
        run_B(OP_ADDI,  4'd10, 4'd1, 18'd100,   a_val + 32'd100,           "ADDI  r10, r1, 100");
        run_B(OP_SUBI,  4'd10, 4'd1, 18'd100,   a_val - 32'd100,           "SUBI  r10, r1, 100");
        run_B(OP_LTI,   4'd11, 4'd1, 18'd1000,  {31'd0, a_val <  32'd1000},"LTI   r11, r1, 1000");
        run_B(OP_EQI,   4'd11, 4'd1, 18'h0_00F0,{31'd0, a_val == 32'h00F0},"EQI   r11, r1, 0f0");
        run_B(OP_GTI,   4'd11, 4'd1, 18'd1000,  {31'd0, a_val >  32'd1000},"GTI   r11, r1, 1000");
        $display("All Type B instructions done");
 
        //Illegal opcode should raises error and writes nothing 
        issue(typeA(6'b011111, 4'd12, 4'd1, 4'd2));
        check_all("illegal opcode", 1'b1);
        $display("PASS: illegal opcode raised error and left registers unchanged");
 
        //  Error clears when a legal instruction is accepted 
        run_A(OP_ADD, 4'd12, 4'd1, 4'd2, a_val + b_val, "ADD r12, r1, r2 after error");
        $display("PASS: error cleared by the next accepted instruction");
 
        //  An out of range shift raises error and writes nothing 
        load_imm(4'd13, 18'd200);                 // 200 is larger than the 32 bit width
        issue(typeA(OP_SLL, 4'd14, 4'd1, 4'd13));
        check_all("shift amount out of range", 1'b1);
        $display("PASS: out of range shift raised error and left registers unchanged");
 
        //  valid low means nothing is accepted 
        run_A(OP_ADD, 4'd15, 4'd1, 4'd2, a_val + b_val, "ADD r15, r1, r2");
        valid = 1'b0;
        instruction = typeA(OP_SUB, 4'd15, 4'd1, 4'd2);  // present but not valid
        repeat (4) @(negedge clk);
        check_all("valid held low", 1'b0);
        $display("PASS: instruction ignored while valid was low");
 
        // Writing the same register twice in a row 
        run_B(OP_ADDI, 4'd15, 4'd15, 18'd1, model[15] + 32'd1, "ADDI r15, r15, 1");
        run_B(OP_ADDI, 4'd15, 4'd15, 18'd1, model[15] + 32'd1, "ADDI r15, r15, 1 again");
 
        // Reset clears the registers again 
        @(negedge clk);
        rst = 1'b1;
        repeat (2) @(negedge clk);
        rst = 1'b0;
        @(negedge clk);
        for (int i = 0; i < NUM_REGS; i++) model[i] = '0;
        check_all("after second reset", 1'b0);
        $display("Second reset check done");
 
        if (errors == 0) $display("All tests passed");
        else             $display("%0d test(s) failed", errors);
        $finish;
    end
endmodule
