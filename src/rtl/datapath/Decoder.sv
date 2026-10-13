//Extract RS1, RS2, RD, IMM from the instruction 
module Decoder (
    input logic [31:0] data_in,
    input logic Type_R, Type_I, Type_S, Type_SB, Type_U, Type_UJ,
    output logic [4:0] RS1, RS2, RD,
    output logic [31:0] IMM
);

always_comb begin 
    RS1 = '0; RS2 = '0; RD = '0; IMM = '0;
    unique0 case (1'b1) //warning if more than one condition is true at the same time
        Type_R: begin
            RS1 = data_in[19:15];
            RS2 = data_in[24:20];
            RD  = data_in[11:7];
        end
        Type_I: begin
            RS1 = data_in[19:15];
            RD  = data_in[11:7];
            IMM = {{20{data_in[31]}}, data_in[31:20]};//keep data in c2c
        end
        Type_S: begin
            RS1 = data_in[19:15];
            RS2 = data_in[24:20];
            IMM = {{20{data_in[31]}}, data_in[31:25], data_in[11:7]};
        end
        Type_SB: begin
            RS1 = data_in[19:15];
            RS2 = data_in[24:20];
            IMM = {{20{data_in[31]}}, data_in[7], data_in[30:25], data_in[11:8],1'b0};
        end
        Type_U: begin
            RD = data_in[11:7];
            IMM = {data_in[31:12],12'b0};      
        end
        Type_UJ: begin
            RD = data_in[11:7];
            IMM = {{12{data_in[31]}}, data_in[19:12],data_in[20],data_in[30:21],1'b0};   
        end
    endcase
end
endmodule