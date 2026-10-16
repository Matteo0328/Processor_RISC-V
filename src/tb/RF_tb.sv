`timescale 1ns/1ps

module RF_tb;
    localparam N_TEST = 1000;
    localparam int BW = 8;
    localparam int DEPTH = 8;

    logic clk, rst_n;
    logic [BW-1:0] data_in;
    logic [$clog2(DEPTH)-1:0] read_addr_1, read_addr_2, write_addr;
    logic write_en_n, chip_en;

    logic [BW-1:0] data_out_1, data_out_2;

    // Reference memory
    logic [BW-1:0] expected_mem [0:DEPTH-1];

    // Verification statistics counters
    int error_count = 0;
    int test_count  = 0;

    RF #(
        .BW(BW),
        .DEPTH(DEPTH)
    ) DUT1 (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(data_in),
        .read_addr_1(read_addr_1), 
        .read_addr_2(read_addr_2),
        .write_addr(write_addr),
        .write_en_n(write_en_n),
        .chip_en(chip_en),
        
        .data_out_1(data_out_1), 
        .data_out_2(data_out_2)
    );

    task check_read( //check if read = expected
        input logic [$clog2(DEPTH)-1:0] addr1,
        input logic [$clog2(DEPTH)-1:0] addr2,
        input bit                       is_fatal = 1'b0 // 0: $error (default), 1: $fatal
    );
        logic [BW-1:0] expected1;
        logic [BW-1:0] expected2;

        begin
            test_count++;

            // Drive read addresses and allow combinational read propagation
            read_addr_1 = addr1;
            read_addr_2 = addr2;
            #1;

            if (DUT1.mem[0] !== '0) begin
                $fatal(1, "HARDWARE VIOLATION: Internal register mem[0] was overwritten! Value: 0x%0h", DUT1.mem[0]);
            end
            if (addr1 == 0 || chip_en == 0 )
                expected1 = '0;
            else
                expected1 = expected_mem[addr1];

            if (addr2 == 0 || chip_en == 0)
                expected2 = '0;
            else
                expected2 = expected_mem[addr2];

            // Check read 1
            if (data_out_1 !== expected1) begin
                error_count++;
                if (is_fatal)
                    $fatal(1, "read1 addr=%0d DUT=%h EXPECTED=%h", addr1, data_out_1, expected1);
                else
                    $error("read1 addr=%0d DUT=%h EXPECTED=%h", addr1, data_out_1, expected1);
            end

            // Check read 2
            if (data_out_2 !== expected2) begin
                error_count++;
                if (is_fatal)
                    $fatal(1, "read2 addr=%0d DUT=%h EXPECTED=%h", addr2, data_out_2, expected2);
                else
                    $error("read2 addr=%0d DUT=%h EXPECTED=%h", addr2, data_out_2, expected2);
            end
        end
    endtask

    initial begin //clk
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 0;

        write_en_n = 1;
        chip_en = 0;

        data_in = '0;
        read_addr_1 = '0;
        read_addr_2 = '0;
        write_addr = '0;
  
        for (int i = 0; i < DEPTH; i++) begin
            expected_mem[i] = '0;
        end

        #25;
        @(negedge clk); 
        rst_n = 1;

        $display("=================================");
        $display("      STARTING TEST-BENCH");
        $display("=================================");

        for (int rep = 0; rep < N_TEST; rep ++) begin
            case (rep)
                0: begin //reset test
                    $display("----- Reset test (testing write attempt during reset) -----");
                    rst_n = 0;
                    chip_en = 1;

                    // Stimulate write during reset to ensure reset has absolute priority
                    write_en_n = 0;
                    write_addr = 3;
                    data_in = '1;

                    for (int i = 0; i < DEPTH; i++) begin
                        expected_mem[i] = '0;
                    end 
                    @(posedge clk); #1;

                    //check the entire memory
                    for (int i = 0; i < DEPTH; i++) begin
                        check_read(i, i, 1); 
                    end 

                    // Cleanly deassert write enable before releasing reset
                    write_en_n = 1;
                    write_addr = '0;
                    data_in = '0;
                    rst_n = 1;
                    @(posedge clk);
                end

                1: begin //standby test
                    $display("----- Standby test -----");                  
                    rst_n = 1;
                    chip_en = 0;
                    write_en_n = 1;
                    @(posedge clk); #1;     
                    check_read(1, 2, 1);
                end

                2: begin // Specific Case: Write to address 0
                    $display("----- Attempting to write to address 0 -----");
                    rst_n = 1; 
                    chip_en = 1; 
                    write_en_n = 0;
                    write_addr = 0; 
                    data_in = '1; // Try forcing all 1s
                    read_addr_1 = 0; 
                    read_addr_2 = 0;
                    
                    @(posedge clk); #1;
                    check_read(0, 0, 1);
                end

                3: begin // Specific Case: Simultaneous Read/Write
                    $display("----- Simultaneous Read and Write (Address 5) -----");
                    rst_n = 1;
                    chip_en = 1; 
                    write_en_n = 0;
                    write_addr = 5; 
                    data_in = 8'hAA;
                    read_addr_1 = 5; 
                    read_addr_2 = 5;
                    
                    expected_mem[5] = 8'hAA; // Update the shadow memory
                    
                    @(posedge clk); #1;
                    check_read(5, 5, 1);
                end

                4: begin // Specific Case: Write blocked in Standby mode
                    $display("----- Attempting to write in Standby mode -----");
                    rst_n = 1; 
                    chip_en = 0; 
                    write_en_n = 0; // Chip disabled
                    write_addr = 3; 
                    data_in = 8'hCC;
                    read_addr_1 = 3; 
                    read_addr_2 = 3;
                                            
                    @(posedge clk); #1;
                    check_read(3, 3, 1); // Must read 0 because chip_en = 0
                end

                default: begin // Randomized operations (Reset, Standby, Read/Write)
                    int rand_mode;
                    rand_mode = $urandom_range(0, 99);

                    if (rand_mode < 1) begin //1% probability of random reset
                        $display("----- Triggering random Reset -----");
                        rst_n = 0;
                        chip_en = 1; 
                        
                        // Stimulate arbitrary write and read signals during reset
                        write_en_n  = $urandom_range(0, 1);
                        write_addr  = $urandom_range(0, DEPTH-1);
                        data_in     = $urandom;
                        read_addr_1 = $urandom_range(0, DEPTH-1);
                        read_addr_2 = $urandom_range(0, DEPTH-1);

                        // All hardware registers will be cleared on the clock edge
                        for (int i = 0; i < DEPTH; i++) begin
                            expected_mem[i] = '0;
                        end 

                        @(posedge clk); #1;
                        for (int i = 0; i < DEPTH; i++) begin
                            check_read(i, i, 1); // check the entire memory
                        end

                        // Deassert write enable before exiting reset to prevent accidental writes
                        write_en_n = 1;
                        write_addr = '0;
                        data_in    = '0;
                        rst_n      = 1;
                        @(posedge clk); 
                        
                    end else if (rand_mode < 5) begin //4% probability of random Standby
                        $display("----- Triggering random Standby -----");
                        rst_n = 1;
                        chip_en = 0; // Disable chip
                        write_en_n = $urandom_range(0, 1); // Try random write en
                        
                        write_addr = $urandom_range(0, DEPTH-1);
                        read_addr_1 = $urandom_range(0, DEPTH-1);
                        read_addr_2 = $urandom_range(0, DEPTH-1);
                        data_in = $urandom;
                        
                        // We do NOT update expected_mem because writes are ignored in standby

                        @(posedge clk); #1;
                        // check_read will correctly expect 0 because chip_en = 0
                        check_read(read_addr_1, read_addr_2, 1); 

                    end else begin //95% probability of normal read/write
                        rst_n = 1;
                        chip_en = 1; 

                        write_en_n = $urandom_range(0, 1);
                        data_in = $urandom;
                        write_addr = $urandom_range(0, DEPTH-1);
                        read_addr_1 = $urandom_range(0, DEPTH-1);
                        read_addr_2 = $urandom_range(0, DEPTH-1);

                        // Update shadow memory if a valid write occurs
                        if (write_addr != 0 && write_en_n == 0) begin
                            expected_mem[write_addr] = data_in;
                        end   

                        @(posedge clk); #1;
                        check_read(read_addr_1, read_addr_2, 0);
                    end
                end
            endcase
        end

        $display("");
        $display("=================================");
        $display("          TEST COMPLETE          ");
        $display("=================================");
        $display("Total checks performed : %0d", test_count);
        $display("Total errors detected  : %0d", error_count);

        if (error_count == 0) begin
            $display("STATUS: ALL TESTS PASSED");
        end else begin
            $display("STATUS: TEST FAILED WITH %0d ERRORS", error_count);
            $fatal(1, "[TB FAILURE] Register file verification failed.");
        end
        $display("=================================");

        $stop;
    end
endmodule