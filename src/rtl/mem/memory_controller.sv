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
endmodule
