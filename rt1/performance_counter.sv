// =============================================================================
// performance_counter.sv
// 
// Performance monitoring - counts blocks processed and cycles elapsed
//
// Author: Person 4 (Top-Level Integration + Measurement)
// =============================================================================

module performance_counter #(
    parameter COUNTER_WIDTH = 32
) (
    input  logic                        clk,
    input  logic                        rst_n,
    
    // Event Inputs
    input  logic                        block_completed,  // Pulse when block exits
    
    // Counter Outputs
    output logic [COUNTER_WIDTH-1:0]    blocks_processed,
    output logic [COUNTER_WIDTH-1:0]    cycles_elapsed
);

    // Block counter - increments when block_completed is high
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            blocks_processed <= '0;
        else if (block_completed)
            blocks_processed <= blocks_processed + 1;
    end
    
    // Cycle counter - free-running
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cycles_elapsed <= '0;
        else
            cycles_elapsed <= cycles_elapsed + 1;
    end

endmodule
