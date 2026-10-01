module Register #(
    parameter int WIDTH = 32
) (
    input logic clk, rst_n, load,
    input logic [WIDTH-1:0] d_in,
    output logic [WIDTH-1:0] d_out
);

always_ff @( posedge clk or negedge rst_n ) begin
    if(!rst_n) 
        d_out <= '0;
    else if (load)
        d_out <= d_in;
end
    
endmodule