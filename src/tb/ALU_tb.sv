`timescale 1ns/1ps

`include "../rtl/pkg/common_pkg.sv"
import alu_pkg::*;

module ALU_tb;

    localparam N_TEST = 2500;

    localparam longint SIGNED_MAX =  (longint'(1) << 31) - 1;
    localparam longint SIGNED_MIN = -(longint'(1) << 31);

    // Corner-case operands 
    localparam int N_CORNERS = 12;
    localparam logic [31:0] CORNERS [N_CORNERS] = '{
        '0, 32'h1, 32'h2, 32'h1F, 32'h20,
        32'h7FFF_FFFF,      // INT_MAX
        32'h8000_0000,      // INT_MIN
        32'hFFFF_FFFF,      // all ones
        32'hFFFF_FFFE, 32'h5555_5555, 32'hAAAA_AAAA, 32'h8000_0001
    };


    logic [31 : 0] in_a;    // operand A
    logic [31 : 0] in_b;    // operand B
    alu_op_t ALU_op;        // operation code   
    
    logic [31 : 0] out;     // output result
    alu_flags_t flags;      // flags of the result


    int error_count = 0;
    int test_count  = 0;

    ALU DUT (in_a, in_b, ALU_op, out, flags);
    
    // obtain the ref output
    function automatic logic [31:0] ref_result (alu_op_t op, logic [31:0] a, logic [31:0] b);
        longint signed a_sign;
        longint signed b_sign;
        int unsigned shamt;

        a_sign = $signed(a);
        b_sign = $signed (b);
        shamt = b[$clog2(32)-1:0];

        case (op)
            ADD:     return a_sign + b_sign;       
            SUB:     return a_sign - b_sign;
            SLL:     return a << shamt;                     // logical left
            SRL:     return a >> shamt;                     // logical right (zero fill)
            SRA:     return $signed(a) >>> shamt;           // arithmetic right (sign fill)
            SLT:     return a_sign < b_sign;                // signed compare   -> 0 or 1
            SLTU:    return a < b;                          // unsigned compare -> 0 or 1
            XOR:     return a ^ b;
            OR:      return a | b;
            AND:     return a & b;
            PASS_B:  return b;
            default: return '0;                             // illegal opcode
        endcase    
    endfunction

// obtain the ref flags
    function automatic alu_flags_t ref_flags (alu_op_t op, logic [31:0] a, logic [31:0] b, logic [31:0] exp_out);
        alu_flags_t f;
        longint signed exact;
        longint signed a_sign, b_sign;

        a_sign = $signed(a);
        b_sign = $signed(b);

        f = '0;

        // overflow: only ADD / SUB, true when the exact result does not fit 
        if (op == ADD || op == SUB) begin
            exact      = (op == ADD) ? (a_sign + b_sign) : (a_sign - b_sign);
            f.overflow = (exact > SIGNED_MAX) || (exact < SIGNED_MIN);
        end

        f.zero     = (exp_out == '0);
        f.negative = exp_out[31];
 
        return f;
    endfunction 

    // Operand generation (corner biased)
    function automatic logic [31:0] rand_operand();
        randcase 
            1: return '0; //all zero
            1: return '1; //all one
            1: return {1'b1, {31{1'b0}}};
            1: return ~{1'b1, {31{1'b0}}};
            2: return $urandom_range(0, 40);          // small values / shift amounts
            2: return 1'b1 << $urandom_range(0, 31);      // one-hot
            2: return ~(1'b1 << $urandom_range(0, 31));   // one-cold
            10: return $urandom;
        endcase
    endfunction


    // random legal opcode 
   function automatic alu_op_t rand_op();
       alu_op_t op;
       op = op.first();
       repeat ($urandom_range(0, op.num()-1)) op = op.next(); 
       return op;
   endfunction

    // check result
    task automatic check_result(input logic [31:0] expected);
        if (out !== expected) begin
            error_count++;
            $error("%s a=%h b=%h out DUT=%h EXPECTED=%h", ALU_op.name(), in_a, in_b, out, expected);
        end
    endtask

    //check flags
    task automatic check_flags(input alu_flags_t expected);
        if (flags.zero !== expected.zero) begin
            error_count++;
            $error("%s a=%h b=%h zero DUT=%b EXPECTED=%b", ALU_op.name(), in_a, in_b, flags.zero, expected.zero);
        end
 
        if (flags.negative !== expected.negative) begin
            error_count++;
            $error("%s a=%h b=%h negative DUT=%b EXPECTED=%b", ALU_op.name(), in_a, in_b, flags.negative, expected.negative);
        end
 
        if (flags.overflow !== expected.overflow) begin
            error_count++;
            $error("%s a=%h b=%h overflow DUT=%b EXPECTED=%b", ALU_op.name(), in_a, in_b, flags.overflow, expected.overflow);
        end
    endtask

    //check ALU operations
    task automatic check_alu(alu_op_t op, logic[31:0] a, logic[31:0]b);
        logic [31:0] exp_out;
        alu_flags_t exp_flags;

        in_a = a;
        in_b = b;
        ALU_op = op;
        #1;

        exp_out = ref_result(op,a,b);
        exp_flags = ref_flags(op,a,b,exp_out);

        check_result(exp_out);
        check_flags (exp_flags);  

        test_count ++;
    endtask 

    // run the same operands through every opcode of the enum
    task automatic check_all_ops(input logic [31:0] a, input logic [31:0] b);
        alu_op_t op;
        op = op.first();
        for (int i = 0; i < op.num(); i++) begin
            check_alu(op, a, b);
            op = op.next();
        end
    endtask

    initial begin
        in_a = '0;
        in_b = '0;
        ALU_op = ADD;
        #10;

        $display("=================================");
        $display("      STARTING TEST-BENCH");
        $display("=================================");

        $display ("----- Corner cross -----");
        //Test any possible combination between corners for every operands
        foreach (CORNERS[i])
            foreach(CORNERS[j])
                check_all_ops(CORNERS[i], CORNERS[j]);

        $display("----- Random tests -----");
        repeat(N_TEST)
            check_alu(rand_op(), rand_operand(), rand_operand());

        $display("=================================");
        $display("          TEST COMPLETE          ");
        $display("=================================");
        $display("Total checks performed : %0d", test_count);
        $display("Total errors detected  : %0d", error_count);

        if (error_count == 0) begin
            $display("STATUS: ALL TESTS PASSED");
        end else begin
            $display("STATUS: TEST FAILED WITH %0d ERRORS", error_count);
            $fatal(1, "[TB FAILURE] ALU verification failed.");
        end
        $display("=================================");
 
        $stop;
    end

endmodule