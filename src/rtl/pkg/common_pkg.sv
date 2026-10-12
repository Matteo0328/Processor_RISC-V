`ifndef COMMON_PKG_SV
`define COMMON_PKG_SV

// Definitions of shared data types and structures for the ALU
package alu_pkg;
    typedef struct packed {
        logic overflow; // asserted on signed arithmetic overflow (ADD/SUB)
        logic negative; // asserted when MSB of result is 1
        logic zero;     // asserted when result is zero
    } alu_flags_t;

    typedef enum logic [3:0] {
        ADD     = 4'b0000,          // addition
        SUB     = 4'b0001,          // subtraction
        SLL     = 4'b0010,          // logical left shift
        SLT     = 4'b0100,          // set less than (signed)
        SLTU    = 4'b0110,          // set less than (unsigned)
        XOR     = 4'b1000,          // logic XOR
        SRL     = 4'b1010,          // logical right shift
        SRA     = 4'b1011,          // arithmetic right shift
        OR      = 4'b1100,          // logic OR
        AND     = 4'b1110,          // logic AND
        PASS_B  = 4'b1111           // passthrough B
    } alu_op_t;
endpackage 


package ctrl_pkg;

    typedef enum logic [1:0] { 
        fetch = 2'b00,
        exec1 = 2'b01,
        exec2 = 2'b10
    } state_t;


    typedef enum logic [6:0] { 
        R_to_R      = 7'b0110011,
        Imm         = 7'b0010011,
        LUI         = 7'b0110111,
        AUIPC       = 7'b0010111,
        Loads       = 7'b0000011,
        Stores      = 7'b0100011,
        Cond_b      = 7'b1100011,
        JAL         = 7'b1101111,
        JALR        = 7'b1100111
    } instr_type_t;

endpackage

`endif