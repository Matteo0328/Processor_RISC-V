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