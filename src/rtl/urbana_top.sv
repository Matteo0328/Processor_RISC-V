module urbana_top #(
    parameter int HALF_FAST = 500_000,    // f_cpu = 100 MHz / (2*HALF_PERIOD) = 100 Hz
    parameter int HALF_SLOW = 5_000_000    // f_cpu = 100 MHz / (2*HALF_PERIOD) = 10 Hz
    )(
    input logic CLK_100MHZ,
    input logic [15:0] SW,
    output logic [15:0] LED,
    output logic [7:0] D1_SEG,
    output logic [3:0] D1_AN,
    output logic [7:0] D0_SEG,
    output logic [3:0] D0_AN
);
// ----- Select clk speed -----
logic [1:0] speed_sync = '0;
logic slow_mode;

always_ff @( posedge CLK_100MHZ ) begin
    speed_sync <= {speed_sync[0], SW[15]};
end
assign slow_mode = speed_sync[1];

// ------ CPU clk generation ------

logic [$clog2(HALF_SLOW)-1:0] div_cnt = '0;
logic [$clog2(HALF_SLOW)-1:0] half_period;
logic cpu_clk_r = 1'b0;
logic cpu_clk;

assign half_period = slow_mode ? HALF_SLOW : HALF_FAST;

always_ff @( posedge CLK_100MHZ ) begin 
    if(div_cnt >= half_period - 1) begin
        div_cnt <= '0;
        cpu_clk_r <= ~cpu_clk_r;
    end else
        div_cnt <= div_cnt + 1'b1;
end
BUFG u_bufg (.I(cpu_clk_r), .O(cpu_clk)); // dedicated connections for clk


// -------Reset ------

logic [1:0] rst_sync;
logic rst_n;

always_ff @( posedge cpu_clk or negedge SW[0] ) begin 
    if(!SW[0]) rst_sync <= 2'b00;
    else rst_sync <= {rst_sync, 1'b1}; // synchronous release
end
assign rst_n = rst_sync[1];

// ------CPU-----
logic [31:0] bus_addr, bus_wdata, bus_pc;
logic [3:0]  bus_write_en;
logic bus_read_en, mem_ready;

CPU_system u_sys (
    .clk(cpu_clk),
    .rst_n(rst_n),
    .bus_addr(bus_addr),
    .bus_wdata(bus_wdata),
    .bus_write_en(bus_write_en),
    .bus_read_en(bus_read_en),
    .bus_mem_ready(mem_ready), 
    .bus_pc(bus_pc)
);

//----- Last data written in mem -----
logic [15:0] last_wdata;
always_ff @( posedge cpu_clk or negedge rst_n ) begin 
    if(!rst_n) last_wdata <= '0;
    else if (|bus_write_en && mem_ready) last_wdata <= bus_wdata[15:0];
end

// ------ LED ------
assign LED = {8'b0, bus_write_en, mem_ready, bus_read_en, cpu_clk, rst_n};

// ------ Display ------
    function automatic logic [7:0] hex7seg(input logic [3:0] h); 
        case (h)
            4'h0: return 8'hC0; 
            4'h1: return 8'hF9; 
            4'h2: return 8'hA4; 
            4'h3: return 8'hB0;
            4'h4: return 8'h99; 
            4'h5: return 8'h92; 
            4'h6: return 8'h82; 
            4'h7: return 8'hF8;
            4'h8: return 8'h80;
            4'h9: return 8'h90; 
            4'hA: return 8'h88; 
            4'hB: return 8'h83;
            4'hC: return 8'hC6;
            4'hD: return 8'hA1;
            4'hE: return 8'h86; 
            4'hF: return 8'h8E;
            default: return 8'hFF;
        endcase
    endfunction

    logic [17:0] refresh_cnt = '0;
    logic [1:0]  sel;

    always_ff @( posedge CLK_100MHZ ) begin 
        refresh_cnt <= refresh_cnt + 1'b1;
    end
    assign sel = refresh_cnt[17:16]; // ~381 HZ for digit

    assign D0_AN = ~(4'b1000 >> sel);
    assign D1_AN = ~(4'b1000 >> sel);
    assign D0_SEG = hex7seg(last_wdata[4*sel +: 4]);
    assign D1_SEG = hex7seg(bus_pc[4*sel +: 4]);
endmodule 