module memory_system (
    input logic clk, rst_n,
    input logic [31:0] addr,data_in,
    input logic [3:0] write_en,
    input logic read_en,
    output logic [31:0] data_out,
    output logic mem_ready
);
    memory_controller ctr_unit(
        .clk(clk),
        .rst_n(rst_n),
        .write_en(write_en),
        .read_en(read_en),
        .mem_ready(mem_ready)
    );

    data_sram mem_unit(
        .clka(clk),
        .addra(addr),
        .dina(data_in),
        .douta(data_out),
        //enable the memory if we have a write or a read operation
        .ena(read_en | (write_en != '0)),
        .wea(write_en)
    );
endmodule