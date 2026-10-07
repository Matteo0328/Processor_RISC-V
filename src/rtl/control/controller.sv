`include "../pkg/common_pkg.sv" 
import alu_pkg::*;
import ctrl_pkg::*;

module Controller (
    input logic clk,rst_n, 
    //From Datapath signal
    input logic [31:0] instr,
    //From Memory signals
    input logic mem_ready,
    //To memory signals
    output logic read_en,

    //To Datapath signals
    output logic Type_R, Type_I, Type_S, Type_SB, Type_U, Type_UJ, //Decoder
    output logic SgnE_8, SgnE_16, PT, ZrE_8, ZrE_16, // Extension
    output logic ldALU, ldMEM, ldPC, // RF_IN
    output logic ce, we_n, //RF
    output logic selImm_PC, selIJump,selINC_PC, //PC_IN
    output logic selZero_cond, selNZero_cond, //J_cond
    output logic selRS1, selPC, //A
    output logic selRS2, selImm, //B
    output alu_op_t ALU_op, //ALU
    output logic ld_SB, ld_SH, ld_SW, // Data_Aligner, Store_Encoder
    output logic selPC_addr, selALU_addr, //Addr_Mem
    //enable signal of registers
    output logic loadIR, loadPC
);
logic [6:0] opcode;
logic [2:0] func3;
logic [6:0] func7; 
//for Immediate operation we need to check also imm[11:5] this signal is equivalent to func7

assign opcode  = instr[6:0];
assign func3   = instr[14:12];
assign func7   = instr[31:25];

state_t pstate, nstate;



always_ff @( posedge clk or negedge rst_n ) begin
    if (!rst_n)
        pstate <= fetch;
    else
        pstate <= nstate;
end

always_comb begin : sel_nstate
    nstate = fetch;
    case (pstate)
        fetch: 
            nstate = (mem_ready) ? exec1:fetch;
        exec1: begin
            case (opcode) //check the opcode
                Loads:      nstate = exec2;
                Stores:     nstate = exec2;
                default:    nstate = fetch;
            endcase
        end
        exec2: nstate = (mem_ready) ? fetch:exec2;
        default: 
            nstate = fetch;
    endcase
end
//GESTIONE SEGNALI ABILITAZIONE REGISTRI E MEMORIE
always_comb begin : Mem_and_Reg_Ctrl
    selPC_addr = 1'b0;
    selALU_addr = 1'b0;
    read_en = 1'b0;
    selINC_PC = 1'b0;
    loadIR = 1'b0;
    loadPC = 1'b0;
    case (pstate)
        fetch: begin
            selPC_addr  = 1'b1;
            read_en     = 1'b1;
            loadIR      = mem_ready;
        end
        exec1: begin
            if(opcode != Loads && opcode != Stores) begin
                loadPC = 1'b1;
                if (opcode != JAL && opcode != JALR) 
                    selINC_PC = 1'b1;
            end
        end
        exec2: begin
            selALU_addr = 1'b1;
            read_en = (opcode == Loads);
            loadPC = mem_ready;
            selINC_PC = 1'b1;
        end
        default: ;
    endcase
end

always_comb begin : Encoder_flag
    Type_R = (opcode == R_to_R);
    Type_I = ((opcode == Imm) || (opcode == Loads) || (opcode == JALR));
    Type_S = (opcode == Stores);
    Type_SB = (opcode == Cond_b);
    Type_U = ((opcode == LUI) || (opcode == AUIPC));
    Type_UJ = (opcode == JAL);
end

always_comb begin : ALU
    ce              = 1'b0;
    we_n            = 1'b1;
    selRS1          = 1'b0;
    selPC           = 1'b0;
    selRS2          = 1'b0;
    selImm          = 1'b0;
    ALU_op          = ADD; 
    ldALU           = 1'b0;
    ldMEM           = 1'b0;
    ldPC            = 1'b0;
    selImm_PC       = 1'b0;
    selZero_cond    = 1'b0;
    selNZero_cond   = 1'b0;
    case(pstate)
        exec1: begin 
            ce = 1'b1;
            unique case (opcode)
                R_to_R: begin
                    selRS1 = 1'b1;
                    selRS2 = 1'b1;
                    case ({func7,func3}) //in this way we write on RF only right results
                        {7'b0000000, 3'b000}: begin ALU_op = ADD;   ldALU = 1'b1;   we_n = 1'b0; end
                        {7'b0100000, 3'b000}: begin ALU_op = SUB;   ldALU = 1'b1;   we_n = 1'b0; end
                        {7'b0000000, 3'b010}: begin ALU_op = SLT;   ldALU = 1'b1;   we_n = 1'b0; end
                        {7'b0000000, 3'b011}: begin ALU_op = SLTU;  ldALU = 1'b1;   we_n = 1'b0; end
                        {7'b0000000, 3'b100}: begin ALU_op = XOR;   ldALU = 1'b1;   we_n = 1'b0; end
                        {7'b0000000, 3'b001}: begin ALU_op = SLL;   ldALU = 1'b1;   we_n = 1'b0; end
                        {7'b0000000, 3'b101}: begin ALU_op = SRL;   ldALU = 1'b1;   we_n = 1'b0; end
                        {7'b0100000, 3'b101}: begin ALU_op = SRA;   ldALU = 1'b1;   we_n = 1'b0; end
                        {7'b0000000, 3'b110}: begin ALU_op = OR;    ldALU = 1'b1;   we_n = 1'b0; end
                        {7'b0000000, 3'b111}: begin ALU_op = AND;   ldALU = 1'b1;   we_n = 1'b0; end
                        default: ;
                    endcase
                end
                Imm: begin
                    selRS1 = 1'b1;
                    selImm = 1'b1;
                    casez ({func7,func3})
                        {7'b???????, 3'b000}: begin ALU_op = ADD;   ldALU = 1'b1;   we_n = 1'b0; end
                        {7'b???????, 3'b010}: begin ALU_op = SLT;   ldALU = 1'b1;   we_n = 1'b0; end
                        {7'b???????, 3'b011}: begin ALU_op = SLTU;  ldALU = 1'b1;   we_n = 1'b0; end
                        {7'b???????, 3'b100}: begin ALU_op = XOR;   ldALU = 1'b1;   we_n = 1'b0; end
                        {7'b???????, 3'b110}: begin ALU_op = OR;    ldALU = 1'b1;   we_n = 1'b0; end
                        {7'b???????, 3'b111}: begin ALU_op = AND;   ldALU = 1'b1;   we_n = 1'b0; end
                        {7'b0000000, 3'b001}: begin ALU_op = SLL;   ldALU = 1'b1;   we_n = 1'b0; end
                        {7'b0000000, 3'b101}: begin ALU_op = SRL;   ldALU = 1'b1;   we_n = 1'b0; end
                        {7'b0100000, 3'b101}: begin ALU_op = SRA;   ldALU = 1'b1;   we_n = 1'b0; end
                        default: ;
                    endcase
                end
                LUI: begin
                    selImm  = 1'b1;
                    ALU_op  = PASS_B;
                    ldALU   = 1'b1;
                    we_n    = 1'b0;
                end 
                AUIPC: begin
                    selPC   = 1'b1;
                    selImm  = 1'b1;
                    ALU_op  = ADD;
                    ldALU   = 1'b1;
                    we_n    = 1'b0;
                end
                Loads,Stores: begin
                    selRS1 = 1'b1;
                    selImm = 1'b1;
                    ALU_op = ADD;
                end
                Cond_b: begin
                    selRS1 = 1'b1;
                    selRS2 = 1'b1;
                    
                    unique case (func3)
                        3'b000: begin ALU_op = XOR;  selZero_cond  = 1'b1; end
                        3'b001: begin ALU_op = XOR;  selNZero_cond = 1'b1; end
                        3'b100: begin ALU_op = SLT;  selNZero_cond = 1'b1; end
                        3'b101: begin ALU_op = SLT;  selZero_cond  = 1'b1; end
                        3'b110: begin ALU_op = SLTU; selNZero_cond = 1'b1; end
                        3'b111: begin ALU_op = SLTU; selZero_cond  = 1'b1; end 
                        default: ;
                    endcase
                end
                JAL: begin
                    ldPC = 1'b1;
                    selImm_PC = 1'b1;
                    we_n = 1'b0;
                end
                JALR: begin
                    ldPC = 1'b1;
                    selRS1 = 1'b1;
                    selImm = 1'b1;
                    ALU_op = ADD;
                    selIJump = 1'b1;
                    we_n = 1'b0;
                end
                default: ;
            endcase
        end
        exec2: begin
            ce = 1'b1;
            //keep ALU output constant
            if (opcode == Loads || opcode == Stores) begin
                selRS1 = 1'b1;
                selImm = 1'b1;
                ALU_op = ADD;
            end
            //writeback in RF of the data read
            if (opcode == Loads && mem_ready) begin
                ldMEM = 1'b1;
                we_n = 1'b0;
            end
        end
        default: ;
    endcase
end

always_comb begin : Mem_Data_Formatting
    SgnE_8  = 1'b0;
    SgnE_16 = 1'b0;
    PT      = 1'b0;
    ZrE_8   = 1'b0;
    ZrE_16  = 1'b0;
    ld_SB   = 1'b0;
    ld_SH   = 1'b0;
    ld_SW   = 1'b0;

    if (opcode == Loads) begin
        case (func3)
            3'b000: SgnE_8  = 1'b1;
            3'b001: SgnE_16 = 1'b1;
            3'b010: PT      = 1'b1;
            3'b100: ZrE_8   = 1'b1;
            3'b101: ZrE_16  = 1'b1;
            default: ;
        endcase
    end else if (opcode == Stores) begin
        case (func3)
            3'b000: ld_SB   = 1'b1;
            3'b001: ld_SH   = 1'b1;
            3'b010: ld_SW   = 1'b1;
            default: ;
        endcase
    end
end

`ifndef __SYNTHESIS__

always_comb begin : Design_Assertions
    // ----Integrity of FSM----
    assert (pstate inside {fetch, exec1, exec2}) 
        else $error("[FSM ERROR] Invalid FSM state detected: %0d", pstate);


    // ----No write in fetch state----
    if (pstate == fetch) begin
        assert (we_n == 1'b1)
            else $error("[CTRL SAFETY] RF write enable active (we_n=0) during FETCH state");
    end


    // ----Mutual exclusion per functional group----
    // Instruction Type Decoder
    assert ($onehot0({Type_R, Type_I, Type_S, Type_SB, Type_U, Type_UJ}))
        else $error("[CTRL CONFLICT] Multiple instruction type flags asserted simultaneously");

    // Register File Input Source (RF_IN)
    assert ($onehot0({ldALU, ldMEM, ldPC}))
        else $error("[CTRL CONFLICT] Conflict on RF_IN: Multiple writeback sources enabled");

    // Next Program Counter Selection (PC_IN)
    assert ($onehot0({selINC_PC, selImm_PC, selIJump}))
        else $error("[CTRL CONFLICT] Conflict on PC_IN: Multiple jump/increment paths enabled");

    // Memory Address Source (Addr_Mem)
    assert ($onehot0({selPC_addr, selALU_addr}))
        else $error("[CTRL CONFLICT] Memory address collision: Both selPC_addr and selALU_addr are asserted");

    // ALU Operand A Multiplexer
    assert ($onehot0({selRS1, selPC}))
        else $error("[CTRL CONFLICT] ALU Operand A conflict: Both selRS1 and selPC are active");

    // ALU Operand B Multiplexer
    assert ($onehot0({selRS2, selImm}))
        else $error("[CTRL CONFLICT] ALU Operand B conflict: Both selRS2 and selImm are active");

    // Load Extension Format
    assert ($onehot0({SgnE_8, SgnE_16, PT, ZrE_8, ZrE_16}))
        else $error("[CTRL CONFLICT] Load extension conflict: Multiple extension formats selected");

    // Store Alignment Size
    assert ($onehot0({ld_SB, ld_SH, ld_SW}))
        else $error("[CTRL CONFLICT] Store sizing conflict: Multiple store widths selected");

    // Branch Evaluation Flags
    assert ($onehot0({selZero_cond, selNZero_cond}))
        else $error("[CTRL CONFLICT] Branch condition conflict: Both selZero_cond and selNZero_cond asserted");



    // ---- When writing to RF (we_n == 0), exactly ONE source must be selected----
    if (we_n == 1'b0) begin
        assert ($onehot({ldALU, ldMEM, ldPC}))
            else $error("[CTRL LOGIC] we_n asserted with invalid or multiple writeback sources (ldALU/ldMEM/ldPC)");
    end


    // ---- During exec1 of Loads, no writeback----
    if (pstate == exec1 && opcode == Loads) begin
        assert (we_n == 1'b1 && ldMEM == 1'b0)
            else $error("[CTRL TIMING] RF writeback triggered during EXEC1 for LOAD instruction!");
    end


    // ---- Store instructions safety----
    if (opcode == Stores) begin
        // Stores must NEVER write to Register File
        assert (we_n == 1'b1 &&ldMEM)
            else $error("[STORE SAFETY] RF write enabled (we_n=0) during a STORE instruction!");

        // Stores must NEVER assert memory read_en
        if (pstate == exec2) begin
            assert (read_en == 1'b0)
                else $error("[STORE SAFETY] read_en asserted during STORE execution in EXEC2!");
        end
    end


end

`endif

endmodule