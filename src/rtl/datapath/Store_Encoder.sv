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