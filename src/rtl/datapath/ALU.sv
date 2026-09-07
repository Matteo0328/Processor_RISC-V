// Definitions of shared data types and structures for the ALU
package alu_pkg;
    typedef struct packed {
        logic overflow; // asserted on signed arithmetic overflow (ADD/SUB)
        logic negative; // asserted when MSB of result is 1
        logic zero;     // asserted when result is zero
    } alu_flags_t;
endpackage

import alu_pkg::*;



module ALU #(
    parameter int BW = 32
) (
    input logic [BW-1 : 0] in_a,    // operand A
    input logic [BW-1 : 0] in_b,    // operand B
    input logic [3 : 0] opcode,     // operation code   
    
    output logic [BW-1 : 0] out,    // output result
    output alu_flags_t flags       // flags of the result
);  


    typedef enum logic [3:0] {
        ADD     = 4'b0000,          // addition
        SUB     = 4'b0001,          // subtraction
        SLL     = 4'b0010,          // logical left shift
        SLT     = 4'b0100,          // set less than (signed)
        SLTU    = 4'b0110,          // set less than (unsigned)
        XOR     = 4'b1000,          // logic XOR
        SRL     = 4'b1010,          // logical right shift
        SRA     = 4'b1011,          // arithmetic right shift
        OR      = 4'b1100,          // logic OR
        AND     = 4'b1110,          // logic AND
        PASS_B  = 4'b1111           // passthrough B
    } alu_op_t;

    // cast raw input opcode vector to enumerated operation type
    alu_op_t op;
    assign op = alu_op_t'(opcode); 

    logic [$clog2(BW)-1:0] shamt;
    assign shamt = in_b[$clog2(BW)-1:0];


    always_comb begin 
        out = '0;
        flags = '0;

        case (op)
            ADD: begin
                out = in_a + in_b;
                flags.overflow = (in_a[BW-1] == in_b[BW-1]) && (out[BW-1] != in_a[BW-1]);
            end
            SUB: begin
                out = in_a - in_b;
                flags.overflow = (in_a[BW-1] != in_b[BW-1]) && (out[BW-1] != in_a[BW-1]);
            end   
            SLL:        out = in_a << shamt;
            SLT:        out = ($signed(in_a) < $signed(in_b)) ? {{(BW-1){1'b0}}, 1'b1} : '0;
            SLTU:       out = (in_a < in_b) ? {{(BW-1){1'b0}}, 1'b1} : '0;
            XOR:        out = in_a ^ in_b;
            SRL:        out = in_a >> shamt;
            SRA:        out = $signed(in_a) >>> shamt;
            OR:         out = in_a | in_b;
            AND:        out = in_a & in_b;
            PASS_B:     out = in_b;
            default:    out = '0;
        endcase

         //negative and zero flags
        flags.negative = out[BW-1];
        flags.zero = (out == '0);
    end
endmodule