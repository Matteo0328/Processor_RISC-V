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