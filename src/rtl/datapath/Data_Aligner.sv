//Create valid data to be write 
// (In order to write bytes in a word register)
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