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
    localparam N_TEST = 100; //each type of test 
    logic        clk,rst_n; 
    logic [31:0] data_in;
    logic        mem_ready;
    logic [31:0] addr;
    logic [31:0] data_out;
    logic [3:0]  write_en;
    logic        read_en;

    int fail_count = 0;

    //asynchronous reset variables
    bit reset_en   = 0;   
    bit reset_hit  = 0;   
    bit reset_busy = 0;   

    CPU DUT (clk, rst_n, data_in, mem_ready, addr, data_out, write_en, read_en);

    //CPU_cov cov (clk, rst_n, DUT.Controller.pstate, DUT.Datapath.d_out_IR, DUT.Datapath.data_out_1_RF, DUT.Datapath.data_out_2_RF);

    initial begin //clk
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ---- Emulated Memory -----

    localparam int MEM_DEPTH = 16384; //64KiB
    localparam int MEM_AW    = $clog2(MEM_DEPTH); 
    logic [31:0] memory [0:MEM_DEPTH-1];
    logic [MEM_AW-1:0] word_idx;
    assign word_idx = addr[MEM_AW+1:2];
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
        memory[byte_addr[MEM_AW+1:2]] = val;
    endtask 

    function automatic logic [31:0] read_mem( input logic [31:0] byte_addr);
        return memory[byte_addr[MEM_AW+1:2]];
    endfunction

    //Advance execution across one complete instruction cycle
    task automatic step_instruction();
        reset_hit = 0;
        @(posedge clk iff DUT.Controller.pstate != fetch);
        @(posedge clk iff DUT.Controller.pstate == fetch);
        #1;
        wait (!reset_busy);
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

    function automatic logic [31:0] rand_operand();
        randcase
            1:  return 32'h0000_0000;               // Zero
            1:  return 32'hFFFF_FFFF;               // -1
            1:  return 32'h7FFF_FFFF;               // Max positive int
            1:  return 32'h8000_0000;               // Max negative int
            1:  return 32'hAAAA_AAAA;               // Pattern 1010...
            1:  return 32'h5555_5555;               // Pattern 0101...
            2:  return (32'd1 << $urandom_range(0, 31)); // Single bit at 1
            2:  return $urandom_range(1, 15);       // Small positive number
            10: return $urandom();                  // Random value
        endcase
    endfunction

    // ------ R-Type verification ------
    task automatic verify_r_type ();
        riscv_instr_item item = new();
        logic [31:0] pc_curr, opA, opB, exp_res;

        assert (item.randomize() with {opcode == R_to_R;})
            else $fatal(1,"[TB FAIL] Constraint solver failed to randomize R-Type instruction");

        // Generate  data and backdoor-initialize the DUT RF with the selected operands before instruction execution
        opA = (item.rs1 != 0) ? rand_operand() : 32'h0;
        if (item.rs1 == item.rs2) begin
            opB = opA;
        end else begin
            opB = (item.rs2 != 0) ? rand_operand() : 32'h0;
        end
        if (item.rs1 != 0) DUT.Datapath.RF1.mem[item.rs1] = opA;
        if (item.rs2 != 0) DUT.Datapath.RF1.mem[item.rs2] = opB;

        pc_curr = DUT.Datapath.d_out_PC;
        write_mem(pc_curr, item.pack());

        //compute expected result
        exp_res = (item.rd == 0) ? 32'h0 : ref_alu(opA, opB, item.func7, item.func3);

        step_instruction();
        if (reset_hit) return;   // interrupted by a reset: expected values are no longer valid

        if (DUT.Datapath.RF1.mem[item.rd] !== exp_res || DUT.Datapath.d_out_PC !== pc_curr + 4) begin
            $error("[FAIL R-TYPE] rd=%0d f7=%b f3=%b | Exp: %h, Got: %h",
                        item.rd, item.func7, item.func3, exp_res, DUT.Datapath.RF1.mem[item.rd]);
            fail_count++;
        end
    endtask //verify_r_type

    // ------ Imm-Type verification ------
    task automatic verify_imm_type();
        riscv_instr_item item = new();
        logic [31:0] pc_curr, opA, exp_res, simm;

        assert (item.randomize() with {opcode == Imm;})
            else $fatal(1,"[TB FAIL] Constraint solver failed to randomize I-Type instruction");

        // Generate  data and backdoor-initialize the DUT RF with the selected operands before instruction execution
        opA = (item.rs1 != 0) ? rand_operand() : 32'h0;
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
                3'b101: begin
                        if (item.imm[11:5] == 7'b0100000)
                            exp_res = $signed(opA) >>> item.imm[4:0];
                            else if (item.imm[11:5] == 7'b0000000)
                            exp_res = opA >> item.imm[4:0];
                    end
                default: exp_res = 32'h0;
            endcase
        if (item.rd == 0) exp_res = 32'h0;

        step_instruction();
        if (reset_hit) return;   // interrupted by a reset: expected values are no longer valid
            
        if (DUT.Datapath.RF1.mem[item.rd] !== exp_res || DUT.Datapath.d_out_PC !== pc_curr + 4) begin
                $error("[FAIL I-TYPE] rd=%0d f3=%b | Exp: %h, Got: %h",
                    item.rd, item.func3, exp_res, DUT.Datapath.RF1.mem[item.rd]);
                fail_count++;
        end
    endtask //verify_imm_type

    // ------ LUI verification ------
    task automatic verify_lui();
        riscv_instr_item item = new();
        logic [31:0] pc_curr, exp_res;

        assert (item.randomize() with {opcode == LUI; })
            else $fatal(1, "[TB FATAL] Constraint solver failed to randomize LUI instruction");

        pc_curr = DUT.Datapath.d_out_PC;
        write_mem(pc_curr, item.pack());

        // compute expected result
        exp_res = (item.rd == 5'd0) ? 32'h0 : {item.imm[31:12], 12'h000};

        step_instruction();
        if (reset_hit) return;   // interrupted by a reset: expected values are no longer valid

        if (DUT.Datapath.RF1.mem[item.rd] !== exp_res || DUT.Datapath.d_out_PC !== pc_curr + 4) begin
            $error("[FAIL LUI] rd=%0d | Exp: %h, Got: %h, Exp PC: %h, Got PC: %h",
                    item.rd, exp_res, DUT.Datapath.RF1.mem[item.rd], pc_curr + 4, DUT.Datapath.d_out_PC);
            fail_count++;
        end
    endtask //verify_lui

    // ------ AUIPC verification ------
    task automatic verify_auipc();
        riscv_instr_item item = new();
        logic [31:0] pc_curr, exp_res;

            assert (item.randomize() with {opcode == AUIPC; })
            else $fatal(1, "[TB FATAL] Constraint solver failed to randomize AUIPC instruction");
        pc_curr = DUT.Datapath.d_out_PC;
        write_mem(pc_curr, item.pack());

        // compute expected result
        exp_res = (item.rd == 5'd0) ? 32'h0 : (pc_curr + {item.imm[31:12], 12'h000});

        step_instruction();
        if (reset_hit) return;   // interrupted by a reset: expected values are no longer valid

        if (DUT.Datapath.RF1.mem[item.rd] !== exp_res || DUT.Datapath.d_out_PC !== pc_curr + 4) begin
                $error("[FAIL AUIPC] rd=%0d | Exp: %h, Got: %h, Exp PC: %h, Got PC: %h",
                    item.rd, exp_res, DUT.Datapath.RF1.mem[item.rd], pc_curr + 4, DUT.Datapath.d_out_PC);
                fail_count++;
            end
    endtask //verify_auipc

    // ------ Load-Type verification ------
    task automatic verify_load();
        riscv_instr_item item = new();
        logic [31:0] opA, simm, eff, pc_curr, word, exp_res;
        logic [7:0] b;
        logic [15:0] h;
        

        assert(item.randomize() with {opcode == Loads;})
            else $fatal(1, "[TB FATAL] Constraint solver failed to randomize Load instruction");

        // Generate  data and backdoor-initialize the DUT RF with the selected operands before instruction execution
        opA = (item.rs1 != 0) ? rand_operand() : 32'h0;
        simm = {{20{item.imm[11]}}, item.imm[11:0]};
        eff = opA + simm;
        if (item.rs1 != 0) DUT.Datapath.RF1.mem[item.rs1] = opA;


        pc_curr = DUT.Datapath.d_out_PC;
        write_mem(eff, rand_operand());
        write_mem(pc_curr, item.pack());
        word = read_mem(eff);

        // compute expected result
        b = word[8*eff[1:0] +: 8];
        h = word[16*eff[1] +: 16];

        case (item.func3)
            3'b000:  exp_res = {{24{b[7]}},  b};   // LB
            3'b001:  exp_res = {{16{h[15]}}, h};   // LH
            3'b010:  exp_res = word;               // LW
            3'b100:  exp_res = {24'h0, b};         // LBU
            3'b101:  exp_res = {16'h0, h};         // LHU
            default: exp_res = 32'h0;
        endcase

        if (item.rd == 0) exp_res = 32'h0;

        step_instruction();
        if (reset_hit) return;   // interrupted by a reset: expected values are no longer valid

        if (DUT.Datapath.RF1.mem[item.rd] !== exp_res || DUT.Datapath.d_out_PC !== pc_curr + 4) begin
            $error("[FAIL LOAD] rd=%0d rs1=%0d f3=%b addr=%h | Exp: %h, Got: %h, Exp PC: %h, Got PC: %h",
                item.rd, item.rs1, item.func3, eff, exp_res, DUT.Datapath.RF1.mem[item.rd],
                pc_curr + 4, DUT.Datapath.d_out_PC);
            fail_count++;
        end
    endtask //verify_load

    // ------ Store verification ------
    task automatic verify_store();
        riscv_instr_item item = new();
            logic [31:0] opA, simm, eff, pc_curr, word, exp_res;
        
        assert(item.randomize() with {opcode == Stores;})
            else $fatal(1, "[TB FATAL] Constraint solver failed to randomize Store instruction");

        // Generate  data and backdoor-initialize the DUT RF with the selected operands before instruction execution
        opA = (item.rs1 != 0) ? rand_operand() : 32'h0;
        simm = {{20{item.imm[11]}}, item.imm[11:0]};
        eff = opA + simm;
        if (item.rs2 != 0) DUT.Datapath.RF1.mem[item.rs2] = rand_operand();
        if (item.rs1 != 0) DUT.Datapath.RF1.mem[item.rs1] = opA;
        word = (item.rs2 != 0) ? DUT.Datapath.RF1.mem[item.rs2] : 32'h0;

        pc_curr = DUT.Datapath.d_out_PC;
        write_mem(eff, rand_operand());
        write_mem(pc_curr, item.pack());

        //modify only the written byte
        exp_res = read_mem(eff);
        case (item.func3)
            3'b000:     exp_res[8*eff[1:0] +: 8] = word[7:0];     // SB
            3'b001:     exp_res[16*eff[1] +: 16] = word[15:0];// SH
            3'b010:     exp_res = word;        // SW
            default: ;
        endcase
        
        step_instruction();
        if (reset_hit) return;   // interrupted by a reset: expected values are no longer valid

        if (read_mem(eff) !== exp_res || DUT.Datapath.d_out_PC !== pc_curr + 4) begin
            $error("[FAIL STORE] rs1=%0d rs2=%0d f3=%b addr=%h | Exp: %h, Got: %h, Exp PC: %h, Got PC: %h",
                item.rs1, item.rs2, item.func3, eff, exp_res, read_mem(eff),
                pc_curr + 4, DUT.Datapath.d_out_PC);
            fail_count++;
        end
    endtask //verify_store

    // ------ C. Branches verification ------
    task automatic verify_branch();
        riscv_instr_item item = new();
        logic [31:0]  pc_curr, opA, opB, exp_pc;
        logic taken;

        assert(item.randomize() with {opcode == Cond_b; imm[1:0] == 2'b00;})
            else $fatal(1, "[TB FATAL] Constraint solver failed to randomize Branch instruction");

        // Generate  data and  backdoor-initialize the DUT RF with the selected operands before instruction execution
        opA = (item.rs1 != 0) ? rand_operand() : 32'h0;
        opB = (item.rs2 != 0) ? (($urandom_range(0, 9) == 0) ? opA : rand_operand()) : 32'h0; // 10% prob of getting opA == opB
        if (item.rs1 == item.rs2) opB = opA;
        if (item.rs1 != 0) DUT.Datapath.RF1.mem[item.rs1] = opA;
        if (item.rs2 != 0) DUT.Datapath.RF1.mem[item.rs2] = opB;

        pc_curr = DUT.Datapath.d_out_PC;
        write_mem(pc_curr, item.pack());

        // compute expected next PC

        case (item.func3) 
            3'b000: taken = (opA == opB); 
            3'b001: taken = (opA != opB);
            3'b100: taken = ($signed(opA) < $signed(opB));
            3'b101: taken = ($signed(opA) >= $signed(opB));
            3'b110: taken = (opA < opB);
            3'b111: taken = (opA >= opB);
            default: taken = 1'b0;
        endcase
        
        exp_pc = taken ? pc_curr + {{19{item.imm[12]}}, item.imm[12:1], 1'b0} : pc_curr + 4;

        step_instruction();
        if (reset_hit) return;   // interrupted by a reset: expected values are no longer valid

            if (DUT.Datapath.d_out_PC !== exp_pc) begin
            $error("[FAIL BRANCH] rs1=%0d rs2=%0d f3=%b | A=%h B=%h imm=%0d taken=%b | Exp PC: %h, Got PC: %h",
                item.rs1, item.rs2, item.func3, opA, opB, $signed(item.imm[12:0]), taken,
                exp_pc, DUT.Datapath.d_out_PC);
            fail_count++;
        end
    endtask //verify_branch

    // ------ JAL verification ------
    task automatic verify_jal();
        riscv_instr_item item = new();
        logic [31:0] pc_curr, exp_pc, exp_rd;

        assert (item.randomize() with { opcode == JAL; imm[1:0] == 2'b00;})
                else $fatal(1, "[TB FATAL] Constraint solver failed to randomize JAL instruction");

        pc_curr = DUT.Datapath.d_out_PC;
        write_mem(pc_curr, item.pack());

        //compute expected result
        exp_rd = (item.rd == 0) ? 32'h0 : pc_curr + 4;
        exp_pc = pc_curr + {{11{item.imm[20]}}, item.imm[20:1], 1'b0};

        step_instruction();
        if (reset_hit) return;   // interrupted by a reset: expected values are no longer valid

        if (DUT.Datapath.RF1.mem[item.rd] !== exp_rd || DUT.Datapath.d_out_PC !== exp_pc) begin
            $error("[FAIL JAL] rd=%0d imm=%0d | Exp rd: %h, Got: %h, Exp PC: %h, Got PC: %h",
                item.rd, $signed(item.imm[20:0]), exp_rd, DUT.Datapath.RF1.mem[item.rd],
                exp_pc, DUT.Datapath.d_out_PC);
            fail_count++;
        end   
    endtask //verify_jal

    // ------ JALR verification ------
    task automatic verify_jalr();
        riscv_instr_item item = new();
        logic [31:0] pc_curr, opA, exp_pc, exp_rd;

        assert (item.randomize() with { opcode == JALR; imm[1:0] == 2'b00;})
                else $fatal(1, "[TB FATAL] Constraint solver failed to randomize JALR instruction");

        // Generate data and backdoor-initialize the DUT RF with the selected operand before instruction execution
        opA = (item.rs1 != 0) ? rand_operand() : 32'h0;
        if (item.rs1 != 0) DUT.Datapath.RF1.mem[item.rs1] = opA;

        pc_curr = DUT.Datapath.d_out_PC;
        write_mem(pc_curr, item.pack());

        //compute expected result
        exp_rd = (item.rd == 0) ? 32'h0 : pc_curr + 4;
        exp_pc = (opA + {{20{item.imm[11]}}, item.imm[11:0]}) & ~(32'b11);

        step_instruction();
        if (reset_hit) return;   // interrupted by a reset: expected values are no longer valid

        if (DUT.Datapath.RF1.mem[item.rd] !== exp_rd || DUT.Datapath.d_out_PC !== exp_pc) begin
            $error("[FAIL JALR] rd=%0d rs1=%0d | A=%h imm=%0d | Exp rd: %h, Got: %h, Exp PC: %h, Got PC: %h",
                item.rd, item.rs1, opA, $signed(item.imm[11:0]), exp_rd, DUT.Datapath.RF1.mem[item.rd],
                exp_pc, DUT.Datapath.d_out_PC);
            fail_count++;
        end 
    endtask //verify_jalr


    // ---- Main verification flow ------
    initial begin
        rst_n = 0;
        #25;
        rst_n = 1;

        step_instruction();

        reset_en = 1;

        $display("==================================================");
        $display("   STARTING RISC-V CPU VERIFICATION ");
        $display("==================================================");
        
        $display("\n[PHASE 1] Executing Randomized R-Type Instructions...");
        repeat(N_TEST) verify_r_type ();

        $display("\n[PHASE 2] Executing Randomized Imm-Type Instructions...");
        repeat(N_TEST) verify_imm_type ();

        $display("\n[PHASE 3] Executing U-Type Instructions...");
        repeat (N_TEST/2) begin
            verify_lui();
            verify_auipc();
        end

        $display("\n[PHASE 4] Executing Randomized Load Instructions...");
        repeat (N_TEST) verify_load();

        $display("\n[PHASE 5] Executing Randomized Store Instructions...");
        repeat (N_TEST) verify_store();

        $display("\n[PHASE 6] Executing Randomized Branch Instructions...");
        repeat (N_TEST) verify_branch();

        $display("\n[PHASE 7] Executing Randomized JAL Instructions...");
        repeat (N_TEST) verify_jal();

        $display("\n[PHASE 8] Executing Randomized JALR Instructions...");
        repeat (N_TEST) verify_jalr();

        $display("\n[PHASE 9] Executing Mixed Random Instructions...");
        repeat (N_TEST * 8) begin
        randcase
                2: verify_r_type();
                2: verify_imm_type();
                1: verify_lui();
                1: verify_auipc();
                2: verify_load();
                2: verify_store();
                2: verify_branch();
                1: verify_jal();
                1: verify_jalr();
            endcase
        end

        if (fail_count == 0)
            $display(">>> No testbench check failed (check the transcript for RTL assertion errors) <<<\n");
        else
            $display(">>> TEST COMPLETED WITH %0d FAILURES <<<\n", fail_count);
        $stop;
    end


    // ------ Random asynchronous reset ----

    task automatic check_reset_state();
    int nz = 0;
    for (int i = 0; i < 32; i++)
        if (DUT.Datapath.RF1.mem[i] !== 32'h0) nz++;

    if (DUT.Controller.pstate !== fetch || DUT.Datapath.d_out_PC !== 32'h0 ||DUT.Datapath.d_out_IR !== 32'h0 || nz != 0) begin
        $error("[FAIL RESET] pstate=%0d PC=%h IR=%h RF nonzero=%0d", 
                DUT.Controller.pstate, DUT.Datapath.d_out_PC, DUT.Datapath.d_out_IR, nz);
        fail_count++;
    end

endtask
    initial begin
        wait (reset_en);
        forever begin
            repeat ($urandom_range(20, 200)) @(posedge clk);
            #($urandom_range(20, 99) / 10.0);

            reset_busy = 1;
            reset_hit  = 1;
            rst_n      = 0;
            write_mem(32'h0, 32'h0000_0013);   // after reset the CPU restarts from address 0: NOP
            #1;
            check_reset_state();

            // send data to the CPU and try to write the memory
            repeat ($urandom_range(2, 5)) begin
                force mem_ready = rand_operand();
                force data_in   = rand_operand();
                @(posedge clk);
            end

            // verify reset
            begin
                automatic int nz = 0;
                for (int i = 0; i < 32; i++)
                    if (DUT.Datapath.RF1.mem[i] !== 32'h0) nz++;
                
                if (DUT.Controller.pstate !== fetch || DUT.Datapath.d_out_PC !== 32'h0 ||
                    DUT.Datapath.d_out_IR !== 32'h0 || nz != 0) begin
                    $error("[FAIL RESET] pstate=%0d PC=%h IR=%h RF nonzero=%0d mem_ready=%b",
                        DUT.Controller.pstate, DUT.Datapath.d_out_PC, DUT.Datapath.d_out_IR, nz, mem_ready);
                    fail_count++;
                end
            end

            release mem_ready;
            release data_in;
            @(negedge clk);
            rst_n = 1;

            // wait for the restart NOP to complete
            @(posedge clk iff DUT.Controller.pstate != fetch);
            @(posedge clk iff DUT.Controller.pstate == fetch);
            reset_busy = 0;
        end
    end

endmodule