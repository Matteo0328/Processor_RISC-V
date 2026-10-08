`timescale 1ns/1ps

`include "../rtl/pkg/common_pkg.sv"
import alu_pkg::*;
import ctrl_pkg::*;


class riscv_instr_item;
    rand logic [6:0]    opcode;
    rand logic [2:0]    func3;
    rand logic [6:0]    func7;
    rand logic [4:0]    rs1,rs2,rd;
    rand logic [31:0]   imm;

    constraint c_valid_opcode {
        opcode inside {
            R_to_R,
            Imm,
            LUI,
            AUIPC,
            Loads,
            Stores,
            Cond_b,
            JAL,
            JALR 
        };
    }
    //Test the access to reg0 of RF
    constraint c_reg {
        rs1 dist {5'd0 := 5, [5'd1:5'd31] := 95};
        rs2 dist {5'd0 := 5, [5'd1:5'd31] := 95};
        rd  dist {5'd0 := 5, [5'd1:5'd31] := 95};
    }

    constraint c_rtype {
        if (opcode == R_to_R) {
            if(func3 inside {3'b000, 3'b101}) 
                func7 inside {7'b0000000, 7'b0100000};
            else
                func7 == 7'b0000000;
        }
    }

    constraint c_itype {
        if(opcode == Imm) {
            if(func3==3'b001)
                imm[11:5] == 7'b0000000;
            else if(func3==3'b101)
                imm[11:5] inside {7'b0000000, 7'b0100000};
        } else if(opcode == Loads){
            func3 inside {3'b000, 3'b001, 3'b010, 3'b100, 3'b101};
        } else if(opcode == JALR) {
            func3 == 3'b000;
        }
    }

    constraint c_stype {
        if(opcode == Stores)
            func3 inside {3'b000, 3'b001, 3'b010};
    }

    constraint c_sbtype {
        if(opcode == Cond_b) 
            func3 inside {3'b000, 3'b001, 3'b100, 3'b101, 3'b110, 3'b111};
    }

    // based on the opcode we build the instruction message

    function logic [31:0] pack();
        case (opcode)
            R_to_R:             return{func7, rs2, rs1, func3, rd, opcode}; //R-type
            Imm, Loads, JALR:   return{imm[11:0], rs1, func3, rd, opcode}; //I-type
            LUI, AUIPC:         return{imm[31:12], rd, opcode}; //U-type
            Stores:             return{imm[11:5], rs2, rs1, func3, imm[4:0], opcode}; //S-type
            Cond_b:             return{imm[12], imm[10:5], rs2, rs1, func3, imm[4:1], imm[11], opcode}; //SB-type
            JAL:                return{imm[20], imm[10:1], imm[11], imm[19:12], rd, opcode}; //UJ-type
            default: $display("Error: Generation of a non valid opcode");
        endcase
        
    endfunction
endclass //riscv_instr_item

task automatic taskName(arguments);
    
endtask //automatic

module CPU_tb;

    logic        clk,rst_n; 
    logic [31:0] data_in;
    logic        mem_ready;
    logic [31:0] addr;
    logic [31:0] data_out;
    logic [3:0]  write_en;
    logic        read_en;


    CPU DUT (clk, rst_n, data_in, mem_ready, addr, data_out, write_en, read_en);

    initial begin //clk
        clk = 0;
        forever #5 clk = ~clk;
    end


    task automatic test_r_type(arguments);
        
    endtask //automatic
endmodule