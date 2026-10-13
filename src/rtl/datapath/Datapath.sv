`include "../pkg/common_pkg.sv" 
import alu_pkg::*;


module Datapath (
    input logic clk,rst_n, 
    input logic Type_R, Type_I, Type_S, Type_SB, Type_U, Type_UJ, //Decoder
    input logic SgnE_8, SgnE_16, PT, ZrE_8, ZrE_16, // Extension
    input logic ldALU, ldMEM, ldPC, // RF_IN
    input logic ce, we_n, //RF
    input logic  selImm_PC, selIJump,selINC_PC, //PC_IN
    input logic selZero_cond, selNZero_cond, //J_cond
    input logic selRS1, selPC, //A
    input logic selRS2, selImm, //B
    input alu_op_t ALU_op, //ALU
    input logic ld_SB, ld_SH, ld_SW, // Data_Aligner, Store_Encoder
    input logic selPC_addr, selALU_addr, //Addr_Mem
    input logic [31:0] data_in, //from memory
    //enable signal of registers
    input logic loadIR, loadPC,
    output logic [31:0] addr, data_out, //to memory
    output logic [3:0] write_en,
    output logic [31:0] inst_out, //to controller
    output logic [31:0] d_out_PC //to CPU
);  
    //RF signals
    logic [31:0] data_in_RF, data_out_1_RF, data_out_2_RF;
    logic [4:0] Raddr_1_RF, Raddr_2_RF, Waddr_RF;
    //ALU signals
    logic [31:0] in_a_ALU, in_b_ALU, out_ALU;
    alu_flags_t flags_ALU;
    //Decoder signals
    logic [31:0] d_out_IR, Imm;
    //Memory signal
    logic [31:0] addr_MEM;
    // Extension signals
    logic [31:0] out_ext;
    // PC signals
    logic [31:0] d_in_PC;


    //other internal signals
    logic JC_out;

    ALU ALU1 (in_a_ALU, in_b_ALU, ALU_op, out_ALU, flags_ALU);

    RF RF1 (clk, rst_n, data_in_RF, Raddr_1_RF, Raddr_2_RF, Waddr_RF, we_n, ce, data_out_1_RF, data_out_2_RF);

    Decoder DEC1 (d_out_IR, Type_R, Type_I, Type_S, Type_SB, Type_U, Type_UJ, Raddr_1_RF, Raddr_2_RF, Waddr_RF, Imm);

    Extension EXT1(data_in, SgnE_8, SgnE_16, PT, ZrE_8, ZrE_16, addr_MEM[1:0], out_ext);

    Data_Aligner DA1(data_out_2_RF, ld_SB, ld_SH, ld_SW, data_out);

    Store_Encoder SE1(addr_MEM[1:0], ld_SB, ld_SH, ld_SW, write_en);

    //mux definitions

    MUX2x1 A(data_out_1_RF, d_out_PC, selRS1, selPC, in_a_ALU);
    MUX2x1 B(data_out_2_RF, Imm, selRS2, selImm, in_b_ALU);
    MUX2x1 AM(d_out_PC, out_ALU, selPC_addr, selALU_addr, addr_MEM);
    MUX3x1 RF_IN(out_ALU, out_ext, (d_out_PC+4), ldALU, ldMEM, ldPC, data_in_RF);
    MUX2x1#(1) JC (flags_ALU.zero, (~flags_ALU.zero), selZero_cond, selNZero_cond, JC_out);
    MUX3x1 PC_IN( (Imm+d_out_PC), (out_ALU & ~(32'b11)),(d_out_PC+4), (JC_out| selImm_PC), selIJump, (selINC_PC | (~JC_out & (selZero_cond | selNZero_cond))), d_in_PC);

    //register definition
    Register PC(clk, rst_n, loadPC, d_in_PC, d_out_PC);
    Register IR(clk, rst_n, loadIR, data_in, d_out_IR);


    //connect addr_MEM to addr
    assign addr = addr_MEM;
    
    //signal to controller
    assign inst_out = d_out_IR;

    // validity of the PC
    `ifndef SYNTHESIS
        always_ff @( posedge clk ) begin
            if (rst_n) begin
                assert (!$isunknown(d_out_PC))
                    else $error("[PC CORRUPTED] PC contains 'X' or 'Z'! PC: 0x%08h", d_out_PC);
                assert (d_out_PC[1:0] == 2'b00)
                    else $error("[PC MISALIGNED] PC is not 4-byte aligned! Current PC: 0x%08h", d_out_PC);
            end
        end
    `endif
endmodule