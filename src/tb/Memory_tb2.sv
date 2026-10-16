`timescale 1ns / 1ps

module tb_memory_system_verify();

    // Signals
    logic clk;
    logic rst_n;
    logic [31:0] addr;
    logic [31:0] data_in;
    logic [3:0]  write_en;
    logic        read_en;
    logic [31:0] data_out;
    logic        mem_ready;

    // Clock Generation
    always #5 clk = ~clk;

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

// write task and verify mem_ready
    task write_and_verify(input [31:0] t_addr, input [31:0] t_data, input [3:0] t_we);
        int wait_cycles;
        begin
            wait_cycles = 0;
            @(posedge clk);
            
            addr = t_addr; data_in = t_data; write_en = t_we; read_en = 0;

            // If write_en is 0000, the memory controller probably ignores the request.
            // We should not wait for mem_ready in this case.
            if (t_we == 4'b0000) begin
                @(posedge clk); // Just hold the signals for one cycle
                write_en = 4'b0000;
            end else begin
                // mem_ready must be 0 at this moment
                if (mem_ready !== 1'b0) 
                    $fatal("[TIMING ERROR] mem_ready is high while sending the WRITE command!");

                // Wait for it to go to 1 with a safety timeout
                while (mem_ready == 1'b0) begin
                    @(posedge clk);
                    wait_cycles++;
                    if (wait_cycles > 10)
                        $fatal("[FATAL ERROR] Timeout! mem_ready stuck at 0 during WRITE.");
                end

                write_en = 4'b0000;

                // Check for return to zero
                @(posedge clk);
                #1;
                if (mem_ready !== 1'b0)
                    $display("[TIMING ERROR] mem_ready remained high for more than one cycle during WRITE!");
            end
        end
    endtask

    // read task and verify mem_ready
    task read_and_verify(input [31:0] t_addr);
        int wait_cycles;
        begin
            wait_cycles = 0;
            @(posedge clk);
            
            addr = t_addr; write_en = 4'b0000; read_en = 1'b1;

            // mem_ready must be 0 at this moment
            if (mem_ready !== 1'b0) 
                $fatal("[TIMING ERROR] mem_ready is high while sending the READ command!");

            // Wait for it to go to 1 with a safety timeout
            while (mem_ready == 1'b0) begin
                @(posedge clk);
                wait_cycles++;
                if (wait_cycles > 10) begin
                    $fatal("[FATAL ERROR] Timeout! mem_ready stuck at 0 during READ.");
                    $finish;
                end
            end

            read_en = 1'b0;

            // Check for return to zero
            @(posedge clk);
            #1;
            if (mem_ready !== 1'b0)
                $display("[TIMING ERROR] mem_ready remained high for more than one cycle during READ!");
        end
    endtask


    initial begin
        // Initialization
        clk = 0; rst_n = 0; addr = 0; data_in = 0; write_en = 0; read_en = 0;

        #25; rst_n = 1; #10;
        
        repeat(3) @(posedge clk);

        // Loop through various test cases
        for (int i = 0; i < 9; i++) begin
            case (i)
                0: begin
                    $display("\n--- CASE 0: Basic Write and Read ---");
                    write_and_verify(32'h0000_0004, 32'hAABBCCDD, 4'b1111);
                    read_and_verify(32'h0000_0004);
                    
                    // Data Verification
                    if (data_out !== 32'hAABBCCDD) 
                        $display("[DATA ERROR] Expected AABBCCDD, Got %h", data_out);
                end
                
                1: begin
                    $display("\n--- CASE 1: Partial Write (Byte Enable) ---");
                    write_and_verify(32'h0000_0008, 32'h11223344, 4'b1111);
                    write_and_verify(32'h0000_0008, 32'hFFFFFFFF, 4'b0011);
                    read_and_verify(32'h0000_0008);
                    
                    // Data Verification (Checking if only lower 2 bytes were overwritten)
                    if (data_out !== 32'h1122FFFF) 
                        $display("[DATA ERROR] Expected 1122FFFF, Got %h", data_out);
                end
                
                2: begin
                    $display("\n--- CASE 2: Boundary Addresses (0x0 and MAX) ---");
                    write_and_verify(32'h0000_0000, 32'hDEADC0DE, 4'b1111);
                    read_and_verify(32'h0000_0000);
                    
                    if (data_out !== 32'hDEADC0DE) 
                        $display("[DATA ERROR] Expected DEADC0DE at 0x0, Got %h", data_out);
                    
                    write_and_verify(32'hFFFF_FFFC, 32'hBEEFBEEF, 4'b1111);
                    read_and_verify(32'hFFFF_FFFC);
                    
                    if (data_out !== 32'hBEEFBEEF) 
                        $display("[DATA ERROR] Expected BEEFBEEF at MAX, Got %h", data_out);
                end
                
                3: begin
                    $display("\n--- CASE 3: Empty Write Command (WE = 0) ---");
                    write_and_verify(32'h0000_000C, 32'h12345678, 4'b1111); // Initialize first
                    write_and_verify(32'h0000_000C, 32'h99999999, 4'b0000); // Try to overwrite with WE=0
                    read_and_verify(32'h0000_000C);
                    
                    // Data Verification (Ensure original data was not overwritten)
                    if (data_out !== 32'h12345678) 
                        $display("[DATA ERROR] Expected 12345678 (no overwrite), Got %h", data_out);
                end

                4: begin
                    $display("\n--- CASE 4: Read from uninitialized memory ---");
                    read_and_verify(32'h0000_0010);
                    
                    // Usually returns 'X' or '0' depending on the memory model
                    if (data_out !== 32'hxxxxxxxx && data_out !== 32'h00000000) 
                        $display("[WARNING] Expected xxxxxxxx or 00000000, Got %h", data_out);
                end
                
                5: begin
                    $display("\n--- CASE 5: R/W Conflict (Robustness) ---");
                    @(posedge clk);
                    addr = 32'h0000_0004; 
                    data_in = 32'h12345678; 
                    write_en = 4'b1111; 
                    read_en = 1'b1;
                    
                    // Wait a few cycles to see how the protocol reacts
                    repeat(5) @(posedge clk);
                    write_en = 4'b0000;
                    read_en = 1'b0;
                end
                6: begin
                    $display("\n--- CASE 6: Single-Byte Isolated Writes ---");
                    write_and_verify(32'h0000_000C, 32'h11223344, 4'b1111);
                    
                    // Overwrite of LSB 
                    write_and_verify(32'h0000_000C, 32'h000000AA, 4'b0001);
                    
                    // Overwrite of Byte 2
                    write_and_verify(32'h0000_000C, 32'h00BB0000, 4'b0100);
                    
                    read_and_verify(32'h0000_000C);
                    
                    if (data_out !== 32'h11BB33AA)
                        $display("[DATA ERROR] Expected 11BB33AA, Got %h", data_out);
                end

                7: begin
                    $display("\n--- CASE 7: Back-to-Back Write and Read ---");
                    @(posedge clk);
                    addr = 32'h0000_0010; data_in = 32'h5A5A5A5A; write_en = 4'b1111; read_en = 1'b0;
                    
                    wait(mem_ready == 1'b1);
                    
                    @(posedge clk);
                    // Change from write to read at the same time
                    write_en = 4'b0000;
                    read_en = 1'b1;
                    
                    wait(mem_ready == 1'b1);
                    @(posedge clk);
                    read_en = 1'b0;
                    
                    if (data_out !== 32'h5A5A5A5A)
                        $display("[DATA ERROR] Expected 5A5A5A5A, Got %h", data_out);
                end

             8: begin
                $display("\n--- CASE 8: Mid-transaction Reset (Asynchronous) ---");
                @(posedge clk);
                addr = 32'h0000_0020; data_in = 32'hDEADDEAD; write_en = 4'b1111;
            
                #2; 
                
                rst_n = 0;          // asynchronous reset call
                write_en = 4'b0000; 
            
                #4; 
                
                rst_n = 1; 
                
                read_and_verify(32'h0000_0020);
                
                if (data_out === 32'hDEADDEAD)
                    $display("[FAIL] Data was written despite reset!");
            end

            default: $display("\n--- Unmapped case ---");
                
            endcase
            
            #20; 
        end

        #30;
        $display("\n--- TEST COMPLETED ---");
        $finish;
    end

endmodule