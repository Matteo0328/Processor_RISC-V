//Extract RS1, RS2, RD, IMM from the instruction 
module decoder (
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
            IMM = {{20{data_in[31]}}, data_in[31], data_in[7], data_in[30:25], data_in[11:8],1'b0};
        end
        Type_U: begin
            RD = data_in[11:7];
            IMM = {data_in[31:12],12'b0};      
        end
        Type_UJ: begin
            RD = data_in[11:7];
            IMM = {{12{data_in[31]}}, data_in[31], data_in[19:12],data_in[20],data_in[30:21],1'b0};   
        end
    endcase
end
endmodule


//Extend to 32 bit the data read from the memory
module Extension (
    input logic [31:0] data_in,
    input logic Sgn8, Sgn16, PT, Zr8, Zr16,
    input logic [1:0] addr,
    output logic [31:0] data_out
);

    logic [7:0] sel_byte;
    logic [15:0] sel_half;    
    always_comb begin
        case (addr)
            2'b00:   sel_byte = data_in[7:0];
            2'b01:   sel_byte = data_in[15:8];
            2'b10:   sel_byte = data_in[23:16];
            2'b11:   sel_byte = data_in[31:24];
            default: sel_byte = 8'b0;
        endcase
    end

    always_comb begin
        case (addr[1])
            1'b0:    sel_half = data_in[15:0];
            1'b1:    sel_half = data_in[31:16];
            default: sel_half = 16'b0;
        endcase
    end

    always_comb begin 
        data_out = '0;
        unique0 case (1'b1)
            Sgn8: data_out = {{24{sel_byte[7]}}, sel_byte};
            Sgn16: data_out = {{16{sel_half[15]}}, sel_half};
            PT: data_out = data_in;
            Zr8: data_out = {24'b0, sel_byte};
            Zr16: data_out = {16'b0, sel_half};
        endcase

    end
endmodule


//Based on controller and addr[1:0] select the correct write_en
module Store_Encoder (
    input logic [1:0] addr,
    input logic SB, SH, SW,
    output logic [3:0] out
);
    always_comb begin
        out = '0;
        unique0 case (1'b1)
            SB: begin
                case (addr)
                    2'b00:   out = 4'b0001;
                    2'b01:   out = 4'b0010;
                    2'b10:   out = 4'b0100;
                    2'b11:   out = 4'b1000;
                    default: out = 4'b0000;
                endcase
            end
            SH: begin
                case (addr[1])
                    1'b0:    out = 4'b0011;
                    1'b1:    out = 4'b1100;
                    default: out = 4'b0000;
                endcase
            end
            SW: out = 4'b1111; 
        endcase
    end
endmodule


//Replica of LSBs
module Data_Aligner (
    input logic [31:0] data_in,
    input logic SB, SH, SW,
    output logic [31:0] data_out
);
    always_comb begin
        data_out = '0;
        unique0 case (1'b1)
            SB: data_out = {4{data_in[7:0]}};
            SH: data_out = {2{data_in[15:0]}};
            SW: data_out = data_in;
        endcase
    end
endmodule