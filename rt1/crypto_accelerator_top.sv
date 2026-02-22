// =============================================================================
// crypto_accelerator_top.sv
// 
// Top-level module integrating all components:
// - Block Distributor (round-robin scheduler)
// - 4x Encryption Lanes (parallel processing)
// - Output Combiner (reordering)
// - Performance Counter
//
// Author: Person 4 (Top-Level Integration)
// =============================================================================

module crypto_accelerator_top #(
    parameter BLOCK_WIDTH = 32,
    parameter NUM_LANES = 4,
    parameter ENCRYPT_LATENCY = 8,
    parameter COUNTER_WIDTH = 32,
    parameter SEQUENCE_ID_WIDTH = 8
) (
    // Clock and Reset
    input  logic                        clk,
    input  logic                        rst_n,  // Active-low synchronous reset
    
    // Input Stream Interface
    input  logic [BLOCK_WIDTH-1:0]      data_in,
    input  logic                        data_in_valid,
    output logic                        data_in_ready,
    
    // Output Stream Interface
    output logic [BLOCK_WIDTH-1:0]      data_out,
    output logic                        data_out_valid,
    input  logic                        data_out_ready,
    
    // Performance Monitoring
    output logic [COUNTER_WIDTH-1:0]    blocks_processed,
    output logic [COUNTER_WIDTH-1:0]    cycles_elapsed
);

    // =========================================================================
    // Internal Signals - Distributor to Lanes
    // =========================================================================
    logic [BLOCK_WIDTH-1:0]         lane_data_in       [NUM_LANES-1:0];
    logic [SEQUENCE_ID_WIDTH-1:0]   lane_seq_id_in     [NUM_LANES-1:0];
    logic                           lane_valid_in      [NUM_LANES-1:0];
    logic                           lane_ready_in      [NUM_LANES-1:0];
    
    // =========================================================================
    // Internal Signals - Lanes to Combiner
    // =========================================================================
    logic [BLOCK_WIDTH-1:0]         lane_data_out      [NUM_LANES-1:0];
    logic [SEQUENCE_ID_WIDTH-1:0]   lane_seq_id_out    [NUM_LANES-1:0];
    logic                           lane_valid_out     [NUM_LANES-1:0];
    logic                           lane_ready_out     [NUM_LANES-1:0];
    
    // =========================================================================
    // Performance Counter Trigger
    // =========================================================================
    logic block_completed;
    assign block_completed = data_out_valid & data_out_ready;
    
    // =========================================================================
    // Module Instantiations
    // =========================================================================
    
    // Block Distributor - Round-robin scheduler with sequence ID generation
    block_distributor #(
        .BLOCK_WIDTH        (BLOCK_WIDTH),
        .NUM_LANES          (NUM_LANES),
        .SEQUENCE_ID_WIDTH  (SEQUENCE_ID_WIDTH)
    ) u_block_distributor (
        .clk            (clk),
        .rst_n          (rst_n),
        .data_in        (data_in),
        .data_in_valid  (data_in_valid),
        .data_in_ready  (data_in_ready),
        .lane_data      (lane_data_in),
        .lane_seq_id    (lane_seq_id_in),
        .lane_valid     (lane_valid_in),
        .lane_ready     (lane_ready_in)
    );
    
    // Encryption Lanes - Instantiate 4 parallel encryption pipelines
    genvar i;
    generate
        for (i = 0; i < NUM_LANES; i++) begin : gen_encryption_lanes
            encryption_lane #(
                .BLOCK_WIDTH        (BLOCK_WIDTH),
                .SEQUENCE_ID_WIDTH  (SEQUENCE_ID_WIDTH),
                .ENCRYPT_LATENCY    (ENCRYPT_LATENCY)
            ) u_encryption_lane (
                .clk            (clk),
                .rst_n          (rst_n),
                .data_in        (lane_data_in[i]),
                .seq_id_in      (lane_seq_id_in[i]),
                .data_in_valid  (lane_valid_in[i]),
                .data_in_ready  (lane_ready_in[i]),
                .data_out       (lane_data_out[i]),
                .seq_id_out     (lane_seq_id_out[i]),
                .data_out_valid (lane_valid_out[i]),
                .data_out_ready (lane_ready_out[i])
            );
        end
    endgenerate
    
    // Output Combiner - Reorder buffer with sequence ID tracking
    output_combiner #(
        .BLOCK_WIDTH        (BLOCK_WIDTH),
        .NUM_LANES          (NUM_LANES),
        .SEQUENCE_ID_WIDTH  (SEQUENCE_ID_WIDTH)
    ) u_output_combiner (
        .clk            (clk),
        .rst_n          (rst_n),
        .lane_data      (lane_data_out),
        .lane_seq_id    (lane_seq_id_out),
        .lane_valid     (lane_valid_out),
        .lane_ready     (lane_ready_out),
        .data_out       (data_out),
        .data_out_valid (data_out_valid),
        .data_out_ready (data_out_ready)
    );
    
    // Performance Counter - Block and cycle counting
    performance_counter #(
        .COUNTER_WIDTH  (COUNTER_WIDTH)
    ) u_performance_counter (
        .clk                (clk),
        .rst_n              (rst_n),
        .block_completed    (block_completed),
        .blocks_processed   (blocks_processed),
        .cycles_elapsed     (cycles_elapsed)
    );

endmodule
