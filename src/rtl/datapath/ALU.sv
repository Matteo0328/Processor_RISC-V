`include "../pkg/common_pkg.sv"
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