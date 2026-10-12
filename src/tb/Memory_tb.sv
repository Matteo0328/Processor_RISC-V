`timescale 1ns / 1ps

module Memory_tb();

    localparam int N_TEST = 5000;

    // Signals
    logic       clk;
    logic       rst_n;
    logic [31:0] addr, data_in, data_out;
    logic [3:0] write_en;
    logic        read_en;
    logic        mem_ready;

    // DUT Instantiation
    memory_system dut (
        .clk(clk),
        .rst_n(rst_n),
        .addr(addr),
        .data_in(data_in),
        .write_en(write_en),
        .read_en(read_en),
        .data_out(data_out),
        .mem_ready(mem_ready)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    logic [31:0] ref_mem [int]; //0:16383

    logic [31:0] read_data;

    // reset handshake 
    bit reset_en = 0;
    bit reset_hit = 0;
    bit reset_busy = 0;
    int rst_hits [4];

    int num_errors = 0;

    // ----- Value generators -----
    function automatic logic [31:0] rand_data();
        randcase
            1: return 32'h0000_0000;
            1: return 32'hFFFF_FFFF;
            1: return 32'hAAAA_AAAA;
            1: return 32'h5555_5555;
            6: return $urandom();
        endcase
    endfunction

    function automatic logic [31:0] rand_addr();
        logic [13:0] widx;
        logic [1:0] lo;
        randcase
            8: widx = $urandom_range(0, 15); //limit the address to first 16 registers
            1: widx = 14'h3FFF;
        endcase
        lo = $urandom_range(0,3); //addr[1:0] must be ignored by the memory
        return {16'h0, widx, lo};
    endfunction

    // ------ Reference model update ----

    always_ff @(posedge clk) begin : ref_update
    if (rst_n)
        for (int i = 0; i < 4; i++)
            if (write_en[i]) ref_mem[addr[15:2]][8*i +: 8] = data_in[8*i +: 8];
    end

    // ------ Reset -----
    task automatic check_reset();
        assert(dut.ctr_unit.p_state == 2'b00 && mem_ready === 1'b0) //WAIT state
            else begin
                $error("[RESET] p_state=%0d mem_ready=%b (expected WAIT / 0)",
                        dut.ctr_unit.p_state, mem_ready);
                num_errors ++;
            end
    endtask //check_reset

    initial begin
        wait (reset_en);
        forever begin
            repeat ($urandom_range(10, 100)) @(negedge clk);
            #($urandom_range(1, 3));            // mid-cycle, never on a clock edge

            reset_busy = 1;
            reset_hit  = 1;
            rst_hits[dut.ctr_unit.p_state]++;
            rst_n = 0;
            #1;                                 // p_state / mem_ready update in the NBA region
            check_reset();

            repeat ($urandom_range(2, 5)) begin
                @(negedge clk);
                check_reset();
            end

            rst_n      = 1;
            reset_busy = 0;                     // reset_hit is cleared by the driver, not here
        end
    end

    // ---- Write operation -----
    task automatic write_mem();
        @(negedge clk);
        if (!reset_hit) begin
            assert (mem_ready === 1'b1)
                else begin
                    $error("[WRITE] a=%h we=%b: mem_ready not high after 1 cycle", addr, write_en);
                    num_errors++;
                end
        end
        write_en = 0;
    endtask 

    // ---- Read operation ----
    task automatic read_mem();
        @(negedge clk);
        if(!reset_hit)
            assert (mem_ready === 1'b0)
                else begin
                    $error("[READ] a=%h: mem_ready already high after 1 cycle", addr);
                    num_errors++;
                end
        @(negedge clk);
        if(!reset_hit)
            assert(mem_ready === 1'b1)
                else begin
                    $error("[READ] a=%h: mem_ready not high after 2 cycles", addr);
                    num_errors++;
                end

        //read_en active (until mem_ready = 1)
        for (int t = 0; reset_hit && mem_ready !== 1'b1 && t < 20; t++)
            @(negedge clk);

        //update signals
        read_data = data_out;
        read_en = 0;
    endtask 

    //data read vs reference model
    task automatic check_read();
        if (!reset_hit)
            assert (read_data === ref_mem[addr[15:2]])
                else begin
                    $error("[READ] a=%h: got %h, expected %h", addr, read_data, ref_mem[addr[15:2]]);
                    num_errors++;
                end
    endtask 

    // ----- Main -----
    initial begin
        rst_n = 0; addr = 0; data_in = 0; write_en = 0; read_en = 0;
        #25
        check_reset();
        @(negedge clk); 
        rst_n = 1;

        //initialize 
        for (int i = 0; i < 17; i++ ) begin
            addr = (i<16) ? i*4 : 32'h0000_FFFC;
            data_in = rand_data();
            write_en = 4'b1111;
            write_mem();
            @(negedge clk);
        end

        reset_en = 1;

        $display("==================================================");
        $display("         STARTING MEMORY VERIFICATION ");
        $display("==================================================");

        repeat (N_TEST) begin
            wait(!reset_busy);
            @(negedge clk);
            
            addr = rand_addr();

            randcase 
                1: begin //write
                    data_in = rand_data();
                    write_en = $urandom_range(1,15);
                    read_en = 0;
                    write_mem();
                end
                1: begin //read
                    data_in = $urandom();
                    write_en = 0;
                    read_en = 1;
                    read_mem();
                    check_read();
                end
            endcase 
        end

       $display("Resets hit controller state: WAIT=%0d WRITE=%0d READ_1=%0d READ_2=%0d",
                 rst_hits[0], rst_hits[1], rst_hits[2], rst_hits[3]);
        $display("==================================================");
        if (num_errors == 0)
            $display(" SIMULATION PASSED: 0 errors detected (check the transcript for RTL assertion errors) ");
        else
            $display(" SIMULATION FAILED: %0d errors found! ", num_errors);
        $display("==================================================");

        $stop;
    end
endmodule