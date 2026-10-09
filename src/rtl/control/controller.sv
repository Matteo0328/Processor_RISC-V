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
                if (opcode != JAL && opcode != JALR && opcode != Cond_b) 
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
    selIJump        = 1'b0;
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
    end else if (opcode == Stores && pstate == exec2) begin
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
    if (rst_n) begin
        // Validate that the controller is in a legitimate state
        assert (pstate inside {fetch, exec1, exec2}) 
            else $error("[FSM ERROR] Invalid FSM state detected: %0d", pstate);

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

        // Register file Write Invariant
        if (we_n == 1'b0) begin
            assert ($onehot({ldALU, ldMEM, ldPC}))
                else $error("[CTRL LOGIC] we_n asserted with invalid or multiple writeback sources (ldALU/ldMEM/ldPC)");
        end
    end
end

always_comb begin : Instruction_decoding_checks
    if(rst_n && pstate == exec1) begin
        
        // R-Type Instructions
        if (opcode == R_to_R) begin
            assert #0 (Type_R && selRS1 && selRS2 && ldALU && !we_n && ce && loadPC && selINC_PC) 
                else  $error("[DECODE R-TYPE] Invalid control bus configuration during EXEC1");
        end

        // Immediate ALU Instructions
        if (opcode == Imm) begin
            assert #0 (Type_I && selRS1 && selImm && ldALU && !we_n && ce && loadPC && selINC_PC) 
                else  $error("[DECODE I-TYPE] Invalid control bus configuration during EXEC1");
        end

        //Memory Loads (Address Calculation)
        if (opcode == Loads) begin
            assert #0 (Type_I && selRS1 && selImm && ALU_op == ADD && we_n && ce && !loadPC && !read_en) 
                else  $error("[DECODE LOAD EXEC1] Invalid control signals during address calculation phase");
        end

        //Memory Stores (Address Calculation)
        if (opcode == Stores) begin
            assert #0 (Type_S && selRS1 && selImm && ALU_op == ADD && we_n && ce && !loadPC && !read_en) 
                else  $error("[DECODE STORE EXEC1] Invalid control signals during address calculation phase");
        end

        //Conditional Branch Instructions
        if (opcode == Cond_b) begin
            assert #0 (Type_SB && selRS1 && selRS2 && we_n && ce && loadPC && !selINC_PC && (selZero_cond || selNZero_cond)) 
                else  $error("[DECODE BRANCH] Invalid control signals for conditional branch in EXEC1");
        end

        //LUI 
        if (opcode == LUI) begin
            assert #0 (Type_U && selImm && ALU_op == PASS_B && ldALU && !we_n && ce && loadPC && selINC_PC) 
                else  $error("[DECODE LUI] Invalid control signals for LUI in EXEC1");
        end

        //AUIPC
        if (opcode == AUIPC) begin
            assert #0 (Type_U && selPC && selImm && ALU_op == ADD && ldALU && !we_n && ce && loadPC && selINC_PC) 
                else  $error("[DECODE AUIPC] Invalid control signals for AUIPC in EXEC1");
        end

        //JAL
        if (opcode == JAL) begin
            assert #0 (Type_UJ && ldPC && !we_n && ce && loadPC && selImm_PC) 
                else  $error("[DECODE JAL] Invalid control signals for JAL in EXEC1");
        end

        //JALR
        if (opcode == JALR) begin
            assert #0 (Type_I && ldPC && !we_n && ce && 
                    selRS1 && selImm && ALU_op == ADD && loadPC && selIJump)
                else $error("[DECODE JALR] Invalid control signals for JALR in EXEC1");
        end

    end

    if(rst_n && pstate == exec2) begin

        // The address calculation path (rs1 + imm) must remain continuously asserted
        assert #0 (selRS1 && selImm && !selRS2 && !selPC && (ALU_op == ADD))
            else $error("[CTRL LOAD/STORE EXEC2] ALU operands or operation altered during memory phase");

        //Loads Writeback
        if (opcode == Loads) begin
            assert #0 (read_en && selALU_addr)
                else $error("[CTRL LOAD EXEC2] Memory read protocol signals incorrectly driven in EXEC2");
            if (mem_ready) begin
                assert #0 (!we_n && ldMEM && loadPC && selINC_PC)
                    else $error("[CTRL LOAD WB] Register File writeback controls failed to assert upon mem_ready");
            end else begin
                assert #0 (we_n && !loadPC)
                    else $error("[CTRL LOAD STALL] Premature RF write or PC increment before mem_ready assertion");
                end
        end

        // Stores Memory
        if (opcode == Stores) begin
            // Stores must never write to RF or issue memory read requests
            assert #0 (!read_en && selALU_addr && we_n && !ldMEM)
                else $error("[STORE SAFETY] Memory or RF safety protocol violated during store in EXEC2");
            if (mem_ready) begin
                assert #0 (loadPC && selINC_PC)
                    else $error("[CTRL STORE DONE] PC increment failed to assert upon store completion");
            end else begin
                assert #0 (!loadPC)
                    else $error("[CTRL STORE STALL] Premature PC increment before store transaction finalized");
            end
        end
    end
end

// ----Temporal Assertions----

//Asynchronous reset verification
property p_fsm_reset;
    @(posedge clk) (!rst_n) |-> (pstate == fetch);
endproperty
assert property (p_fsm_reset) 
    else $error("[FSM RESET] FSM failed to reset into FETCH state on reset assertion");

//Forward Transitions

//FETCH -> EXEC1
property p_fetch_to_exec1;
    @(posedge clk) disable iff (!rst_n)
    (pstate == fetch && mem_ready) |=> (pstate == exec1);
endproperty
assert property (p_fetch_to_exec1)
    else $error("[FSM TRANS] Failed to advance from FETCH to EXEC1 upon mem_ready assertion");

//EXEC1 -> EXEC2
property p_exec1_to_exec2;
    @(posedge clk) disable iff (!rst_n)
    (pstate == exec1 && (opcode inside {Loads, Stores})) |=> (pstate == exec2);
endproperty
assert property (p_exec1_to_exec2)
    else $error("[FSM TRANS] Multicycle instruction (Load/Store) failed to enter EXEC2 from EXEC1");    

//EXEC1 -> FETCH
property p_exec1_to_fetch;
    @(posedge clk) disable iff (!rst_n)
    (pstate == exec1 && !(opcode inside {Loads, Stores})) |=> (pstate == fetch);
endproperty
assert property (p_exec1_to_fetch)
    else $error("[FSM TRANS] Single-cycle instruction did not return to FETCH after EXEC1");

//EXEC2 -> FETCH
property p_exec2_to_fetch;
    @(posedge clk) disable iff (!rst_n)
    (pstate == exec2 && mem_ready) |=> (pstate == fetch);
endproperty
assert property (p_exec2_to_fetch)
    else $error("[FSM TRANS] Multicycle instruction failed to return to FETCH from EXEC2 upon mem_ready");


// State hold /stall verification (mem_ready low)

// FETCH hold
property p_hold_fetch;
    @(posedge clk) disable iff (!rst_n)
    (pstate == fetch && !mem_ready) |=> (pstate == fetch);
endproperty
assert property (p_hold_fetch)
    else $error("[FSM STALL] FSM left FETCH state prematurely while mem_ready was deasserted");

// EXEC2 hold
property p_hold_exec2;
    @(posedge clk) disable iff (!rst_n)
    (pstate == exec2 && !mem_ready) |=> (pstate == exec2);
endproperty
assert property (p_hold_exec2)
    else $error("[FSM STALL] FSM left EXEC2 state prematurely while mem_ready was deasserted");

// Handshake and latch synchronization 

// IR latch

property p_sync_loadIR;
    @(posedge clk) disable iff(!rst_n)
    (pstate == fetch) ? (loadIR == mem_ready) : (!loadIR);
endproperty
assert property (p_sync_loadIR)
    else $error("[SYNC TIMING] loadIR must be asserted if and only if mem_ready is high in FETCH");

// read_en must drop to 0 when exiting FETCH
property p_sync_read_en_drop;
    @(posedge clk) disable iff (!rst_n)
    (pstate == fetch && mem_ready) |=> (!read_en);
endproperty
assert property (p_sync_read_en_drop)
    else $error("[SYNC TIMING] read_en remained high when entering EXEC1");

// in EXEC2 read_en must be high if and only if it is a Load
property p_sync_read_en_exec2;
    @(posedge clk) disable iff (!rst_n)
    (pstate == exec2) |-> (read_en == (opcode == Loads));
endproperty
assert property (p_sync_read_en_exec2)
    else $error("[SYNC TIMING] read_en mismatch in EXEC2: expected high only for Loads!");

// PCr update timing during EXEC1
    property p_sync_loadPC_exec1;
        @(posedge clk) disable iff (!rst_n)
        (pstate == exec1) |-> (loadPC == !(opcode inside {Loads, Stores}));
    endproperty
    assert property (p_sync_loadPC_exec1)
        else $error("[SYNC TIMING] loadPC assertion mismatch during EXEC1 stage");

// PC update timing during EXEC2: must occur only upon mem_ready
    property p_sync_loadPC_exec2;
        @(posedge clk) disable iff (!rst_n)
        (pstate == exec2) |-> (loadPC == mem_ready);
    endproperty
    assert property (p_sync_loadPC_exec2)
        else $error("[SYNC TIMING] loadPC in EXEC2 must be strictly gated by mem_ready");
`endif

endmodule