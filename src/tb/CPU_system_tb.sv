`timescale 1ns/1ps

module CPU_system_tb;
    localparam logic [31:0] ADDR_COUNTER = 32'h0000_8000;
    localparam logic [31:0] ADDR_OUT = 32'h0000_A000;
    localparam logic [31:0] EXPECTED = 32'h0000_136F;   // 25 + (0+1+...+99) = 4975

    logic        clk, rst_n;
    logic [31:0] bus_addr, bus_wdata;
    logic [3:0]  bus_write_en;
    logic        bus_read_en;
    logic [31:0] bus_pc;

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end 

    CPU_system dut (
        .clk(clk), .rst_n(rst_n),
        .bus_addr(bus_addr), .bus_wdata(bus_wdata),
        .bus_write_en(bus_write_en), .bus_read_en(bus_read_en), .bus_pc(bus_pc)
    );

    int cycles = 0;
    bit done = 0;

    always @(posedge clk) if (rst_n) cycles++;

    // Check final result
    always @(posedge clk) begin
        if (rst_n && !done && |bus_write_en && bus_addr == ADDR_OUT) begin
            done = 1;
            $display("------Final write to 0xA000 completed after %0d clock cycles------", cycles);
            if (bus_wdata === EXPECTED)
                $display(">>> PASS: result = %0d (0x%h)", bus_wdata, bus_wdata);
            else
                $error(">>> FAIL: got %h, expected %h", bus_wdata, EXPECTED);
            #50 $finish;
        end
    end

    initial begin
  
        rst_n = 0;
        #25 rst_n = 1;
        $display("------Starting code execution------");
        #200us;
        if (!done) $error(">>> TIMEOUT: no write to 0xA000 detected");
        $finish;
    end
endmodule