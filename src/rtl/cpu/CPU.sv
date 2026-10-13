`include "../pkg/common_pkg.sv"
import alu_pkg::*;

module CPU (
    input   logic        clk,rst_n, 
    input   logic [31:0] data_in,
    input   logic        mem_ready,
    output  logic [31:0] addr,
    output  logic [31:0] data_out,
    output  logic [3:0]  write_en,
    output  logic        read_en,
    output  logic [31:0] pc
);
    //control signal
    logic [31:0] instr;
    logic Type_R, Type_I, Type_S, Type_SB, Type_U, Type_UJ; //Decoder
    logic SgnE_8, SgnE_16, PT, ZrE_8, ZrE_16; // Extension
    logic ldALU, ldMEM, ldPC; // RF_IN
    logic ce, we_n; //RF
    logic selImm_PC, selIJump,selINC_PC; //PC_IN
    logic selZero_cond, selNZero_cond; //J_cond
    logic selRS1, selPC; //A
    logic selRS2, selImm; //B
    alu_op_t ALU_op; //ALU
    logic ld_SB, ld_SH, ld_SW; // Data_Aligner, Store_Encoder
    logic selPC_addr, selALU_addr; //Addr_Mem

    //enable signal of registers
    logic loadIR, loadPC;

    Datapath Datapath (clk,rst_n,Type_R, Type_I, Type_S, Type_SB, Type_U, Type_UJ,SgnE_8, SgnE_16, PT, ZrE_8, ZrE_16,ldALU, ldMEM, ldPC, ce, we_n, selImm_PC, selIJump,selINC_PC, selZero_cond, selNZero_cond, selRS1, selPC, selRS2, selImm, ALU_op, ld_SB, ld_SH, ld_SW, selPC_addr, selALU_addr, data_in, loadIR, loadPC, addr, data_out, write_en, instr,pc);

    Controller Controller (clk,rst_n, instr, mem_ready, read_en, Type_R, Type_I, Type_S, Type_SB, Type_U, Type_UJ, SgnE_8, SgnE_16, PT, ZrE_8, ZrE_16, ldALU, ldMEM, ldPC, ce, we_n, selImm_PC, selIJump,selINC_PC, selZero_cond, selNZero_cond, selRS1, selPC, selRS2, selImm, ALU_op, ld_SB, ld_SH, ld_SW, selPC_addr, selALU_addr, loadIR, loadPC);
endmodule