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


module CPU_tb;
    localparam N_TEST = 50; //each type of test 
    logic        clk,rst_n; 
    logic [31:0] data_in;
    logic        mem_ready;
    logic [31:0] addr;
    logic [31:0] data_out;
    logic [3:0]  write_en;
    logic        read_en;

    int fail_count = 0;

    CPU DUT (clk, rst_n, data_in, mem_ready, addr, data_out, write_en, read_en);

    initial begin //clk
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ---- Emulated Memory -----

    localparam int MEM_DEPTH = 16384; //64KiB
    logic [31:0] memory [0:MEM_DEPTH-1];
    logic [29:0] word_idx;
    assign word_idx = addr[31:2];
    int read_latency_cnt;

    // Memory initialization 
    initial begin
        for (int i = 0; i < MEM_DEPTH; i++) begin
            memory[i] = 32'h0000_0013;
        end 
    end

    // Handshake responder matching memory_controller
    always_ff @( posedge clk or negedge rst_n ) begin 
        if (!rst_n) begin
            mem_ready           <= 1'b0;
            data_in             <= '0;
            read_latency_cnt    <= 0; 
        end else begin
            if (mem_ready) begin
                mem_ready           <= 1'b0;
                read_latency_cnt    <= 0;
            end else if (|write_en) begin
                if (write_en[0]) memory[word_idx][7:0] <= data_out [7:0];
                if (write_en[1]) memory[word_idx][15:8] <= data_out [15:8];
                if (write_en[2]) memory[word_idx][23:16] <= data_out [23:16];
                if (write_en[3]) memory[word_idx][31:24] <= data_out [31:24];
                mem_ready           <= 1'b1;
                read_latency_cnt    <= 0;
            end else if (read_en) begin
                if (read_latency_cnt == 1) begin
                    data_in             <= memory [word_idx];
                    mem_ready           <= 1'b1;
                    read_latency_cnt    <= 0;
                end else 
                    read_latency_cnt <= read_latency_cnt + 1;
            end else 
                read_latency_cnt <= 0;
        end
    end

// ---- Controller routines ----

    task automatic write_mem(input logic [31:0] byte_addr, input logic [31:0] val);
        memory[byte_addr[31:2]] = val;
    endtask 

    function automatic logic [31:0] read_mem( input logic [31:0] byte_addr);
        return memory[byte_addr[31:2]];
    endfunction

    //Advance execution across one complete instruction cycle
    task automatic step_instruction();
        @(posedge clk iff DUT.Controller.pstate != fetch);
        @(posedge clk iff DUT.Controller.pstate == fetch);
        #1;
    endtask 

// ---- Reference software ALU ----

    function automatic logic [31:0] ref_alu (
        input logic [31:0] a,
        input logic [31:0] b,
        input logic [6:0]  f7,
        input logic [2:0]  f3
    );
        logic [4:0] shamt = b[4:0];
        case ({f7,f3})
            {7'b0000000, 3'b000}: return a + b;
            {7'b0100000, 3'b000}: return a - b;
            {7'b0000000, 3'b001}: return a << shamt;
            {7'b0000000, 3'b010}: return ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            {7'b0000000, 3'b011}: return (a < b) ? 32'd1 : 32'd0;
            {7'b0000000, 3'b100}: return a ^ b;
            {7'b0000000, 3'b101}: return a >> shamt;
            {7'b0100000, 3'b101}: return $signed(a) >>> shamt;
            {7'b0000000, 3'b110}: return a | b;
            {7'b0000000, 3'b111}: return a & b;
            default:              return 32'h0;
        endcase
    endfunction


// ---- R-Type verification ----
task automatic verify_r_type ();
    riscv_instr_item item = new();
    logic [31:0] pc_curr, opA, opB, exp_res;

    assert (item.randomize() with {opcode == R_to_R;})
        else $fatal(1,"[TB FAIL] Constraint solver failed to randomize R-Type instruction");

    // Generate  data and backdoor-initialize the DUT RF with the selected operands before instruction execution
    opA = (item.rs1 != 0) ? $urandom() : 32'h0;
    if (item.rs1 == item.rs2) begin
        opB = opA;
    end else begin
        opB = (item.rs2 != 0) ? $urandom() : 32'h0;
    end
    if (item.rs1 != 0) DUT.Datapath.RF1.mem[item.rs1] = opA;
    if (item.rs2 != 0) DUT.Datapath.RF1.mem[item.rs2] = opB;

    pc_curr = DUT.Datapath.d_out_PC;
    write_mem(pc_curr, item.pack());

    //compute expected result
    exp_res = (item.rd == 0) ? 32'h0 : ref_alu(opA, opB, item.func7, item.func3);

    step_instruction();

    if (DUT.Datapath.RF1.mem[item.rd] !== exp_res || DUT.Datapath.d_out_PC !== pc_curr + 4) begin
        $error("[FAIL R-TYPE] rd=%0d f7=%b f3=%b | Exp: %h, Got: %h",
                    item.rd, item.func7, item.func3, exp_res, DUT.Datapath.RF1.mem[item.rd]);
        fail_count++;
    end
endtask //verify_r_type

// ------ Imm-Type verification -----
task automatic verify_imm_type();
    riscv_instr_item item = new();
    logic [31:0] pc_curr, opA, exp_res, simm;

    assert (item.randomize() with {opcode == Imm;})
        else $fatal(1,"[TB FAIL] Constraint solver failed to randomize I-Type instruction");

    // Generate  data and backdoor-initialize the DUT RF with the selected operands before instruction execution
    opA = (item.rs1 != 0) ? $urandom() : 32'h0;
    simm = {{20{item.imm[11]}}, item.imm[11:0]};
    if (item.rs1 != 0) DUT.Datapath.RF1.mem[item.rs1] = opA;

    pc_curr = DUT.Datapath.d_out_PC;
    write_mem(pc_curr, item.pack());

    //compute expected result
    case (item.func3)
            3'b000: exp_res = opA + simm;
            3'b010: exp_res = ($signed(opA) < $signed(simm)) ? 32'd1 : 32'd0;
            3'b011: exp_res = (opA < simm) ? 32'd1 : 32'd0;
            3'b100: exp_res = opA ^ simm;
            3'b110: exp_res = opA | simm;
            3'b111: exp_res = opA & simm;
            3'b001: exp_res = opA << item.imm[4:0];
            3'b101: exp_res = (item.imm[11:5] == 7'b0100000) ? 
                              ($signed(opA) >>> item.imm[4:0]) : (opA >> item.imm[4:0]);
            default: exp_res = 32'h0;
        endcase
    if (item.rd == 0) exp_res = 32'h0;

    step_instruction();
        
    if (DUT.Datapath.RF1.mem[item.rd] !== exp_res || DUT.Datapath.d_out_PC !== pc_curr + 4) begin
            $error("[FAIL I-TYPE] rd=%0d f3=%b | Exp: %h, Got: %h",
                   item.rd, item.func3, exp_res, DUT.Datapath.RF1.mem[item.rd]);
            fail_count++;
    end
endtask //verify_imm_type


// ---- Main verification flow ----

initial begin
    rst_n = 0;
    #25;
    rst_n = 1;

    step_instruction();

    $display("==================================================");
    $display("   STARTING RISC-V CPU VERIFICATION ");
    $display("==================================================");
    
    $display("\n[PHASE 1] Executing Randomized R-Type Instructions...");
    repeat(N_TEST) verify_r_type ();

    $display("\n[PHASE 1] Executing Randomized Imm-Type Instructions...");
    repeat(N_TEST) verify_imm_type ();

    if (fail_count == 0)
            $display(">>> ALL VERIFICATION TESTS PASSED! <<<\n");
        else
            $display(">>> TEST COMPLETED WITH FAILURES. <<<\n");
    $stop;
end
endmodule