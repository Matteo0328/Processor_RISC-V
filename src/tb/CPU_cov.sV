`include "../rtl/pkg/common_pkg.sv"
    import ctrl_pkg::*;

module CPU_cov

(
    input logic        clk, rst_n,
    input logic [1:0]  pstate,        // FSM state of the controller (1 = exec1)
    input logic [31:0] instr,         // instruction register
    input logic [31:0] opA, opB       // rs1 / rs2 values read from the register file
);
 
    logic [6:0] opcode;
    logic [2:0] f3;
    assign opcode = instr[6:0];
    assign f3     = instr[14:12];
 
    // ---- Load/Store: has every variant been executed? ----
    covergroup cg_mem with function sample(bit is_store, logic [2:0] f3);
        cp_kind : coverpoint is_store { bins load = {0}; bins store = {1}; }
        cp_f3   : coverpoint f3 { bins b = {0}; bins h = {1}; bins w = {2}; bins bu = {4}; bins hu = {5}; }
        cross cp_kind, cp_f3 {
            ignore_bins no_unsigned_store = binsof(cp_kind.store) && (binsof(cp_f3.bu) || binsof(cp_f3.hu));
        }
    endgroup
 
    // ---- Branch: has every condition been both taken and not taken? ----
    covergroup cg_br with function sample(logic [2:0] f3, bit taken);
        cp_f3    : coverpoint f3 { bins beq = {0}; bins bne = {1}; bins blt = {4};
                                   bins bge = {5}; bins bltu = {6}; bins bgeu = {7}; }
        cp_taken : coverpoint taken;
        cross cp_f3, cp_taken;
    endgroup
 
    cg_mem cg_mem_i = new();
    cg_br  cg_br_i  = new();
 
    // ---- Every instruction of the implemented subset: executed at least once? ----
    // key = {alt, func3, opcode}: alt (instr[30]) and func3 are cleared where they are not part of the encoding
    logic [10:0] key;
    always_comb begin
        key = {1'b0, f3, opcode};
        if (opcode inside {LUI, AUIPC, JAL}) key[9:7] = 3'b000;
        if (opcode == R_to_R || (opcode == Imm && f3 == 3'b101)) key[10] = instr[30];
    end
 
    covergroup cg_instr with function sample(logic [10:0] k);
        cp_instr : coverpoint k {
            // R-type
            bins add  = {{1'b0, 3'b000, R_to_R}};  bins sub  = {{1'b1, 3'b000, R_to_R}};
            bins sll  = {{1'b0, 3'b001, R_to_R}};  bins slt  = {{1'b0, 3'b010, R_to_R}};
            bins sltu = {{1'b0, 3'b011, R_to_R}};  bins xor_ = {{1'b0, 3'b100, R_to_R}};
            bins srl  = {{1'b0, 3'b101, R_to_R}};  bins sra  = {{1'b1, 3'b101, R_to_R}};
            bins or_  = {{1'b0, 3'b110, R_to_R}};  bins and_ = {{1'b0, 3'b111, R_to_R}};
            // I-type ALU
            bins addi  = {{1'b0, 3'b000, Imm}};  bins slli = {{1'b0, 3'b001, Imm}};
            bins slti  = {{1'b0, 3'b010, Imm}};  bins sltiu = {{1'b0, 3'b011, Imm}};
            bins xori  = {{1'b0, 3'b100, Imm}};  bins srli = {{1'b0, 3'b101, Imm}};
            bins srai  = {{1'b1, 3'b101, Imm}};  bins ori  = {{1'b0, 3'b110, Imm}};
            bins andi  = {{1'b0, 3'b111, Imm}};
            // Loads / Stores
            bins lb = {{1'b0, 3'b000, Loads}};  bins lh = {{1'b0, 3'b001, Loads}};
            bins lw = {{1'b0, 3'b010, Loads}};  bins lbu = {{1'b0, 3'b100, Loads}};
            bins lhu = {{1'b0, 3'b101, Loads}};
            bins sb = {{1'b0, 3'b000, Stores}}; bins sh = {{1'b0, 3'b001, Stores}};
            bins sw = {{1'b0, 3'b010, Stores}};
            // Branches
            bins beq  = {{1'b0, 3'b000, Cond_b}};  bins bne  = {{1'b0, 3'b001, Cond_b}};
            bins blt  = {{1'b0, 3'b100, Cond_b}};  bins bge  = {{1'b0, 3'b101, Cond_b}};
            bins bltu = {{1'b0, 3'b110, Cond_b}};  bins bgeu = {{1'b0, 3'b111, Cond_b}};
            // U-type and jumps
            bins lui = {{1'b0, 3'b000, LUI}};  bins auipc = {{1'b0, 3'b000, AUIPC}};
            bins jal = {{1'b0, 3'b000, JAL}};  bins jalr  = {{1'b0, 3'b000, JALR}};
        }
    endgroup
 
    cg_instr cg_instr_i = new();
 
    function automatic bit branch_taken(input logic [2:0] f3, input logic [31:0] a, input logic [31:0] b);
        case (f3)
            3'b000:  return (a == b);                      // BEQ
            3'b001:  return (a != b);                      // BNE
            3'b100:  return ($signed(a) <  $signed(b));    // BLT
            3'b101:  return ($signed(a) >= $signed(b));    // BGE
            3'b110:  return (a <  b);                      // BLTU
            3'b111:  return (a >= b);                      // BGEU
            default: return 1'b0;
        endcase
    endfunction
 
    // One sample per executed instruction
    always @(posedge clk iff (rst_n && pstate == 2'b01)) begin
        cg_instr_i.sample(key);
        case (opcode)
            Loads:   cg_mem_i.sample(1'b0, f3);
            Stores:  cg_mem_i.sample(1'b1, f3);
            Cond_b:  cg_br_i.sample(f3, branch_taken(f3, opA, opB));
            default: ;
        endcase
    end
 
    // Printed when the simulation ends (quit / $finish)
    final begin
        $display("---------------- FUNCTIONAL COVERAGE ----------------");
        $display("All instr. : %6.2f %%", cg_instr_i.get_coverage());
        $display("Load/Store : %6.2f %%", cg_mem_i.get_coverage());
        $display("Branch     : %6.2f %%", cg_br_i.get_coverage());
        $display("-----------------------------------------------------");
    end
 
endmodule
 