`include "../pkg/common_pkg.sv"
import alu_pkg::*;


module ALU #(
    parameter int BW = 32
) (
    input logic [BW-1 : 0] in_a,    // operand A
    input logic [BW-1 : 0] in_b,    // operand B
    input alu_op_t ALU_op,     // operation code   
    
    output logic [BW-1 : 0] out,    // output result
    output alu_flags_t flags       // flags of the result
);  


    logic [$clog2(BW)-1:0] shamt;
    assign shamt = in_b[$clog2(BW)-1:0];


    always_comb begin 
        out = '0;
        flags = '0;

        case (ALU_op)
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


`ifndef __SYNTHESIS__

always_comb begin: ALU_assertions
    // Check ALU opcode validity
    assert (ALU_op inside {ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND, PASS_B}) 
        else   $error("[ALU] Unknown ALU operation: %b", ALU_op);
    

    if (ALU_op inside {SLT, SLTU}) begin
        // Upper 31 bits must always be zero
        assert (out[31:1] == 31'b0)
            else $error("[ALU ERROR] Upper 31 bits must be zero for SLT/SLTU! Out: 0x%08h", out);
    end

    //Check zero and negative flag validity
    assert (flags.zero == (out == 32'b0))
        else $error("[ALU FLAG ERROR] Zero flag mismatch! Flag: %b, ALU_out: 0x%08h", flags.zero, out);
    assert (flags.negative == (out[BW-1]))
        else $error("[ALU FLAG ERROR] Negative flag mismatch! Flag: %b, ALU_out: 0x%08h", flags.negative, out[BW-1]);       
end
`endif 
endmodule