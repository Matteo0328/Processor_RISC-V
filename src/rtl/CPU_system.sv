module CPU_system (
    input logic     clk,
    input logic     rst_n,
    output logic [31:0] bus_addr,
    output logic [31:0] bus_wdata,
    output logic [3:0]  bus_write_en,
    output logic        bus_read_en,
    output logic        bus_mem_ready,
    output logic [31:0] bus_pc
);
    logic [31:0]    cpu_rdata;


    CPU u_cpu (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(cpu_rdata),
        .mem_ready(bus_mem_ready),
        .addr(bus_addr),
        .data_out(bus_wdata),
        .write_en(bus_write_en),
        .read_en(bus_read_en),
        .pc(bus_pc)
    );

    memory_system u_mem(
        .clk(clk),
        .rst_n(rst_n),
        .addr(bus_addr),
        .data_in(bus_wdata),
        .write_en(bus_write_en),
        .read_en(bus_read_en),
        .data_out(cpu_rdata),
        .mem_ready(bus_mem_ready)
    );


    `ifndef SYNTHESIS
        logic req;
        assign req = bus_read_en | (|bus_write_en);

        // write and read together should never happen
        property p_no_rw_conflict;
            @(posedge clk) disable iff (!rst_n)
            !(bus_read_en && |bus_write_en);
        endproperty
        assert property (p_no_rw_conflict) 
        else   $error("[BUS] simultaneous read and write requests");
        
        // Request must remain stable until bus_mem_ready arrives
        property p_req_stable;
            @(posedge clk) disable iff (!rst_n)
            (req && !bus_mem_ready) |=> ($stable(bus_addr) && $stable(bus_read_en) && $stable(bus_write_en) && (!(|bus_write_en) || $stable(bus_wdata)));
        endproperty
        assert  property (p_req_stable) 
        else   $error("[BUS] request changed before mem_ready");

        // Response must arrive within maximum latency (2 cycles)
        property p_ready_timeout;
            @(posedge clk) disable iff (!rst_n)
            req |-> ##[0:2] bus_mem_ready;
        endproperty
        assert property (p_ready_timeout)
            else $error("[BUS] timeout waiting for mem_ready");

        // Address must be known whenever a request is active
        property p_addr_known;
            @(posedge clk) disable iff (!rst_n)
            req |-> !$isunknown(bus_addr);
        endproperty
        assert property (p_addr_known)
            else $error("[BUS] address contains X/Z");

        // Read data must be known when it is return
        property p_rdata_known;
            @(posedge clk) disable iff (!rst_n)
            (bus_read_en && bus_mem_ready) |-> !$isunknown(cpu_rdata);
        endproperty
        assert property (p_rdata_known)
            else $error("[BUS] read data contains X/Z (uninitialized memory?)");

        //Load/Store alignment
        property p_aligned_access;
            @(posedge clk) disable iff (!rst_n)
            u_cpu.selALU_addr |->
                    ((u_cpu.instr[13:12] != 2'b01 || !bus_addr[0]) &&          // halfword
                    (u_cpu.instr[13:12] != 2'b10 || bus_addr[1:0] == 2'b00)); // word
        endproperty
        assert property (p_aligned_access)
            else $warning("[CPU] misaligned access, addr=%h", bus_addr);
    `endif
endmodule