`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/19/2026 12:44:25 PM
// Design Name: 
// Module Name: alu
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


module alu #(
    parameter int OP_WIDTH = 8
) (
    input  logic [OP_WIDTH-1:0] op1,
    input  logic [OP_WIDTH-1:0] op2,
    input  logic [3:0] control,
    output logic [OP_WIDTH-1:0] res,
    output logic error
);
    
    localparam logic [3:0] OP_NOT = 4'd0;
    localparam logic [3:0] OP_XOR = 4'd1;
    localparam logic [3:0] OP_AND = 4'd2;
    localparam logic [3:0] OP_OR = 4'd3;
    localparam logic [3:0] OP_XNOR = 4'd4;
    localparam logic [3:0] OP_SLL  = 4'd5;   
    localparam logic [3:0] OP_SRL  = 4'd6;   
    localparam logic [3:0] OP_SRA  = 4'd7; 
    localparam logic [3:0] OP_ADD  = 4'd8;
    localparam logic [3:0] OP_SUB  = 4'd9;
    localparam logic [3:0] OP_LT   = 4'd10;   
    localparam logic [3:0] OP_EQ   = 4'd11;   
    localparam logic [3:0] OP_GT   = 4'd12;   

    always_comb begin
        res   = '0;
        error = 1'b0;

        case (control)
            OP_NOT:  res = ~op1;
            OP_XOR:  res = op1 ^ op2;
            OP_AND:  res = op1 & op2;
            OP_OR:   res = op1 | op2;
            OP_XNOR: res = ~(op1 ^ op2);
            
            OP_SLL:  if (op2 >= OP_WIDTH) error = 1'b1;
                     else                 res   = op1 << op2;
            OP_SRL:  if (op2 >= OP_WIDTH) error = 1'b1;
                     else                 res   = op1 >> op2;
            OP_SRA:  if (op2 >= OP_WIDTH) error = 1'b1;
                     else                 res   = $signed(op1) >>> op2;
            OP_ADD:  res = op1 + op2;
            OP_SUB:  res = op1 - op2;
            
            OP_LT:   res[0] = (op1 <  op2);
            OP_EQ:   res[0] = (op1 == op2);
            OP_GT:   res[0] = (op1 >  op2);
            
            default: error = 1'b1;   
        endcase
    end
endmodule