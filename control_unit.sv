`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/02/2026 02:25:20 PM
// Design Name: 
// Module Name: control_unit
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



module control_unit #(
    parameter int WIDTH      = 32,
    parameter int NUM_REGS   = 16,
    parameter int ADDR_WIDTH = $clog2(NUM_REGS)
) (
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] instruction,
    input  wire        valid,
    output wire        ready,
    output reg         error,
    // Extra channel: every register exposed so the testbench can check writes
    output wire [NUM_REGS*WIDTH-1:0] regs_flat
);


    //  opcode[5] selects the type: 0 = Type A (register), 1 = Type B (immediate)
 
    // ALU operation codes, matching alu.sv
    localparam logic [3:0] ALU_XOR  = 4'd1;
    localparam logic [3:0] ALU_AND  = 4'd2;
    localparam logic [3:0] ALU_OR   = 4'd3;
    localparam logic [3:0] ALU_XNOR = 4'd4;
    localparam logic [3:0] ALU_SLL  = 4'd5;
    localparam logic [3:0] ALU_SRL  = 4'd6;
    localparam logic [3:0] ALU_SRA  = 4'd7;
    localparam logic [3:0] ALU_ADD  = 4'd8;
    localparam logic [3:0] ALU_SUB  = 4'd9;
    localparam logic [3:0] ALU_LT   = 4'd10;
    localparam logic [3:0] ALU_EQ   = 4'd11;
    localparam logic [3:0] ALU_GT   = 4'd12;
 
    // The low five opcode bits pick the operation and are identical for both types
    localparam logic [4:0] FN_AND  = 5'd0;
    localparam logic [4:0] FN_OR   = 5'd1;
    localparam logic [4:0] FN_XOR  = 5'd2;
    localparam logic [4:0] FN_XNOR = 5'd3;
    localparam logic [4:0] FN_SLL  = 5'd4;
    localparam logic [4:0] FN_SRL  = 5'd5;
    localparam logic [4:0] FN_SLA  = 5'd6;
    localparam logic [4:0] FN_SRA  = 5'd7;
    localparam logic [4:0] FN_ADD  = 5'd8;
    localparam logic [4:0] FN_SUB  = 5'd9;
    localparam logic [4:0] FN_LT   = 5'd10;
    localparam logic [4:0] FN_EQ   = 5'd11;
    localparam logic [4:0] FN_GT   = 5'd12;
 
    // State 
    localparam logic S_IDLE = 1'b0;   // waiting for an instruction
    localparam logic S_EXEC = 1'b1;   // decoding and writing back
 
    reg        state;
    reg [31:0] instr_r;   // the accepted instruction
 
    // Ready only while idle and not in reset
    assign ready = (state == S_IDLE) && !rst;
 
    // Decode 
    wire [5:0]            opcode  = instr_r[5:0];
    wire [ADDR_WIDTH-1:0] f_op1   = instr_r[6 +: ADDR_WIDTH];    // destination
    wire [ADDR_WIDTH-1:0] f_op2   = instr_r[10 +: ADDR_WIDTH];   // first source
    wire [ADDR_WIDTH-1:0] f_op3   = instr_r[14 +: ADDR_WIDTH];   // second source (Type A)
    wire [17:0]           f_imm   = instr_r[31:14];              // immediate (Type B)
    wire                  type_b  = opcode[5];
    wire [4:0]            fn      = opcode[4:0];
 
    // Map the opcode onto an ALU control code
    reg [3:0] alu_ctrl;
    reg       illegal;
    always_comb begin
        illegal  = 1'b0;
        case (fn)
            FN_AND:  alu_ctrl = ALU_AND;
            FN_OR:   alu_ctrl = ALU_OR;
            FN_XOR:  alu_ctrl = ALU_XOR;
            FN_XNOR: alu_ctrl = ALU_XNOR;
            FN_SLL:  alu_ctrl = ALU_SLL;
            FN_SRL:  alu_ctrl = ALU_SRL;
            FN_SLA:  alu_ctrl = ALU_SLL;   
            FN_SRA:  alu_ctrl = ALU_SRA;
            FN_ADD:  alu_ctrl = ALU_ADD;
            FN_SUB:  alu_ctrl = ALU_SUB;
            FN_LT:   alu_ctrl = ALU_LT;
            FN_EQ:   alu_ctrl = ALU_EQ;
            FN_GT:   alu_ctrl = ALU_GT;
            default: begin
                alu_ctrl = 4'd0;
                illegal  = 1'b1;           // opcode is not in the ISA
            end
        endcase
    end
 
    // *** Datapath
    wire [WIDTH-1:0] rs_val, rt_val, alu_res;
    wire             alu_error;
 
    // Second ALU operand: a register for Type A, the zero extended immediate for Type B
    wire [WIDTH-1:0] operand_b = type_b ? {{(WIDTH-18){1'b0}}, f_imm} : rt_val;
 
    // Write back only on a legal instruction that the ALU did not flag
    wire do_write = (state == S_EXEC) && !illegal && !alu_error;
 
    register_file #(.WIDTH(WIDTH), .NUM_REGS(NUM_REGS)) rf (
        .clk(clk), .rst(rst),
        .we(do_write), .rd_sel(f_op1), .d_in(alu_res),
        .rs_sel(f_op2), .rs(rs_val),
        .rt_sel(f_op3), .rt(rt_val),
        .regs_flat(regs_flat)
    );
 
    alu #(.OP_WIDTH(WIDTH)) alu_i (
        .op1(rs_val), .op2(operand_b), .control(alu_ctrl),
        .res(alu_res), .error(alu_error)
    );
 
    // Control FSM 
    always_ff @(posedge clk) begin
        if (rst) begin
            state   <= S_IDLE;
            instr_r <= 32'd0;
            error   <= 1'b0;
        end else begin
            case (state)
                S_IDLE: begin
                    if (valid) begin
                        instr_r <= instruction;
                        error   <= 1'b0;      // cleared when a new instruction is accepted
                        state   <= S_EXEC;
                    end
                end
                S_EXEC: begin
                    error <= illegal | alu_error;
                    state <= S_IDLE;
                end
            endcase
        end
    end
endmodule
