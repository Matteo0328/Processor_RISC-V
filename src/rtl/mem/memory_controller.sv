module memory_controller (
    input logic clk, rst_n,
    input logic [3:0] write_en,
    input logic read_en,
    output logic mem_ready
);
    
typedef enum logic [1:0]{WAIT, WRITE, READ_1, READ_2} mem_state_t;
mem_state_t p_state, n_state;

always_ff @( posedge clk or negedge rst_n) begin 
    if(!rst_n)
        p_state <= WAIT;
    else
        p_state <= n_state;
end

always_comb begin 
    n_state = WAIT;

    case (p_state)
        WAIT: begin
            if(write_en) // write_en is prioritize
                n_state = WRITE;
            else if (read_en)
                n_state = READ_1;
        end

        WRITE:
            n_state = WAIT;

        READ_1:
            n_state = READ_2; // wait one clk

        READ_2:    
            n_state = WAIT;
        
        default: n_state = WAIT;
    endcase
end

assign mem_ready = (p_state == READ_2 || p_state == WRITE) ? 1'b1:1'b0;



`ifndef __SYNTHESIS__

    // ---------- Controller checks ----------

    // Reset
    property p_reset;
        @(posedge clk) !rst_n |-> (p_state == WAIT);
    endproperty
    assert property (p_reset)
        else $error("[MEM CTRL] Reset: state is not WAIT");

    // Write: mem_ready must rise one cycle after the request
    property p_write_latency;
        @(posedge clk) disable iff (!rst_n)
        (p_state == WAIT && |write_en) |=> (mem_ready && p_state == WRITE);
    endproperty
    assert property (p_write_latency)
        else $error("[MEM CTRL] Write: mem_ready does not rise after 1 cycle");

    // Read: mem_ready must stay low for 1 cycle and rise on the second 
    property p_read_latency;
        @(posedge clk) disable iff (!rst_n)
        (p_state == WAIT && !(|write_en) && read_en)
            |=> (!mem_ready ##1 mem_ready);
    endproperty
    assert property (p_read_latency)
        else $error("[MEM CTRL] Read: mem_ready does not rise after 2 cycles");

    // No request: mem_ready must not rise on its own
    property p_idle_no_ready;
        @(posedge clk) disable iff (!rst_n)
        (p_state == WAIT && !(|write_en) && !read_en) |=> !mem_ready;
    endproperty
    assert property (p_idle_no_ready)
        else $error("[MEM CTRL] mem_ready high without requests");

    // mem_ready is a single-cycle pulse
    property p_ready_pulse;
        @(posedge clk) disable iff (!rst_n)
        mem_ready |=> !mem_ready;
    endproperty
    assert property (p_ready_pulse)
        else $error("[MEM CTRL] mem_ready high for more than one cycle");

    // mem_ready never X after reset
    assert property (@(posedge clk) disable iff (!rst_n) !$isunknown(mem_ready))
        else $error("[MEM CTRL] mem_ready contains X/Z");

    // ---------- Requester check ----------

    // During READ_1 the request must stay active
    property p_req_hold_read;
        @(posedge clk) disable iff (!rst_n)
        (p_state == READ_1) |-> (read_en && !(|write_en));
    endproperty
    assert property (p_req_hold_read)
        else $error("[PROTOCOL] read_en released before the read completed");

    // Simultaneous read and write: the write wins, the read is lost
    property p_no_rw_conflict;
        @(posedge clk) disable iff (!rst_n)
        !(read_en && |write_en);
    endproperty
    assert property (p_no_rw_conflict)
        else $warning("[PROTOCOL] read_en and write_en both active: the read is ignored");
`endif
endmodule
