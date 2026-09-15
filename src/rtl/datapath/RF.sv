module RF #(
    parameter BW,
    parameter DEPTH
) (
    input logic clk,rst_n,
    input logic [BW-1:0] data_in,
    input logic [$clog2(DEPTH)-1:0] read_addr_1, read_addr_2,
    input logic [$clog2(DEPTH)-1:0] write_addr,
    input logic write_en_n, chip_en,

    output logic [BW-1:0] data_out_1, data_out_2
);

    // Instantiate register
    logic [BW-1:0] mem [DEPTH];

    // Address 0 is hardwired to zero
    assign mem[0] = '0;

    //Read out
    assign data_out_1 = (chip_en && read_addr_1 != 0) ?mem[read_addr_1] : '0;
    assign data_out_2 = (chip_en && read_addr_2 != 0) ?mem[read_addr_2] : '0;


    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin // Reset
            // we neglect mem[0] since it's hardwired to 0
            for (int i = 1; i<DEPTH; i++) begin 
                mem[i] <= '0;
            end
        end else if (chip_en) begin
            if (!write_en_n && write_addr != 0) begin
                mem[write_addr] <= data_in;
            end
        end
        
    end
endmodule