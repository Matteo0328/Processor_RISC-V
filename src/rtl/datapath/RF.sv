module RF #(
    parameter BW = 32,
    parameter DEPTH = 32
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


    //Read out
    assign data_out_1 = (chip_en && read_addr_1 != 0) ?mem[read_addr_1] : '0;
    assign data_out_2 = (chip_en && read_addr_2 != 0) ?mem[read_addr_2] : '0;


    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin // Reset
            for (int i = 0; i<DEPTH; i++) begin 
                mem[i] <= '0;
            end
        end else if (chip_en) begin
            if (!write_en_n && write_addr != 0) begin
                mem[write_addr] <= data_in;
            end
        end
        
    end
    
    `ifndef SYNTHESIS
    // The internal register x0 must ALWAYS remain 0
    always_ff @( posedge clk ) begin
        assert (mem[0] == 32'b0)
            else $fatal(1, "[RF VIOLATION] Register x0 corrupted! Current value: 0x%08h", mem[0]);        
    end
    // Combinational check on read ports when addressing x0
    always_comb begin
        if (rst_n) begin
            if (read_addr_1 == 5'd0) begin
                assert (data_out_1 == 32'b0)
                    else $error("[RF READ ERROR] Port data_out_1 is not zero when reading register x0!");
            end
            if (read_addr_2 == 5'd0) begin
                assert (data_out_2 == 32'b0)
                    else $error("[RF READ ERROR] Port data_out_2 is not zero when reading register x0!");
            end
        end
    end
    `endif 
endmodule