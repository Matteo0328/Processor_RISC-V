//
module MUX2x1 #(
    parameter int WIDTH = 32
)(
    input logic [WIDTH-1:0] A, B,
    input logic sel_A, sel_B,
    output logic [WIDTH-1:0] Y
);
always_comb begin 
    Y = '0;
    unique0 case (1'b1)
        sel_A: Y = A;
        sel_B: Y = B;
    endcase
end
endmodule


//
module MUX3x1 #(
    parameter int WIDTH = 32
)(
    input logic [WIDTH-1:0] A, B, C,
    input logic sel_A, sel_B, sel_C,
    output logic [WIDTH-1:0] Y
);
always_comb begin 
    Y = '0;
    unique0 case (1'b1)
        sel_A: Y = A;
        sel_B: Y = B;
        sel_C: Y = C;
    endcase
end
endmodule


module MUX4x1 #(
    parameter int WIDTH = 32
)(
    input logic [WIDTH-1:0] A, B, C, D, 
    input logic sel_A, sel_B, sel_C, sel_D,
    output logic [WIDTH-1:0] Y
);
always_comb begin 
    Y = '0;
    unique0 case (1'b1)
        sel_A: Y = A;
        sel_B: Y = B;
        sel_C: Y = C;
        sel_D: Y = D;
    endcase
end
endmodule