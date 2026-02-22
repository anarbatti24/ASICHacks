// =============================================================================
// encryption_lane.sv
// 
// 8-stage encryption pipeline with EXACTLY 8-cycle latency
// 8 rounds of encryption in 8 clock cycles
//
// Author: Person 1 (Encryption Lane Designer)
// =============================================================================

module encryption_lane #(
    parameter BLOCK_WIDTH = 32,
    parameter SEQUENCE_ID_WIDTH = 8,
    parameter ENCRYPT_LATENCY = 8
) (
    input  logic                        clk,
    input  logic                        rst_n,
    
    // Input from Distributor
    input  logic [BLOCK_WIDTH-1:0]      data_in,
    input  logic [SEQUENCE_ID_WIDTH-1:0] seq_id_in,
    input  logic                        data_in_valid,
    output logic                        data_in_ready,
    
    // Output to Combiner
    output logic [BLOCK_WIDTH-1:0]      data_out,
    output logic [SEQUENCE_ID_WIDTH-1:0] seq_id_out,
    output logic                        data_out_valid,
    input  logic                        data_out_ready
);

    // =========================================================================
    // Round Keys (8 keys for 8 encryption rounds)
    // =========================================================================
    logic [BLOCK_WIDTH-1:0] round_keys [ENCRYPT_LATENCY-1:0];
    
    assign round_keys[0] = 32'hDEADBEEF;
    assign round_keys[1] = 32'hCAFEBABE;
    assign round_keys[2] = 32'h12345678;
    assign round_keys[3] = 32'h9ABCDEF0;
    assign round_keys[4] = 32'hFEDCBA98;
    assign round_keys[5] = 32'h76543210;
    assign round_keys[6] = 32'hAAAAAAAA;
    assign round_keys[7] = 32'h55555555;

    // =========================================================================
    // Pipeline registers: ENCRYPT_LATENCY-1 intermediate stages (stages 0 to
    // ENCRYPT_LATENCY-2) plus a final output register (stage ENCRYPT_LATENCY-1).
    //
    // True 8-cycle latency pipeline:
    //   Cycle 1 : engine[0] takes raw data_in  -> registered into stage[0]
    //   Cycle 2 : engine[1] takes stage[0]     -> registered into stage[1]
    //   ...
    //   Cycle 8 : engine[7] takes stage[6]     -> registered into stage[7]
    //   Output  : stage[7]  (valid 8 cycles after input accepted)
    // =========================================================================
    logic [BLOCK_WIDTH-1:0]       stage_data   [ENCRYPT_LATENCY-1:0];
    logic [SEQUENCE_ID_WIDTH-1:0] stage_seq_id [ENCRYPT_LATENCY-1:0];
    logic                         stage_valid  [ENCRYPT_LATENCY-1:0];

    // =========================================================================
    // 8 Encrypt Engines (combinational, between register stages)
    // engine[0] is fed directly from the input ports (not a register), so the
    // first register stage captures an already-encrypted value.
    // =========================================================================
    logic [BLOCK_WIDTH-1:0] encrypted [ENCRYPT_LATENCY-1:0];

    // Engine 0: driven by raw data_in
    encrypt_engine #(
        .BLOCK_WIDTH(BLOCK_WIDTH)
    ) engine_0 (
        .data_in   (data_in),
        .round_key (round_keys[0]),
        .data_out  (encrypted[0])
    );

    // Engines 1-7: driven by the previous pipeline register
    genvar i;
    generate
        for (i = 1; i < ENCRYPT_LATENCY; i++) begin : gen_engines
            encrypt_engine #(
                .BLOCK_WIDTH(BLOCK_WIDTH)
            ) engine (
                .data_in   (stage_data[i-1]),
                .round_key (round_keys[i]),
                .data_out  (encrypted[i])
            );
        end
    endgenerate

    // =========================================================================
    // Stall logic
    // The pipeline stalls when the output is valid but the downstream consumer
    // is not ready. While stalled, data_in_ready is de-asserted so the upstream
    // distributor also pauses.
    // =========================================================================
    logic stall;
    assign stall         = data_out_valid && !data_out_ready;
    assign data_in_ready = !stall;

    // =========================================================================
    // Pipeline registers
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int j = 0; j < ENCRYPT_LATENCY; j++) begin
                stage_data[j]   <= '0;
                stage_seq_id[j] <= '0;
                stage_valid[j]  <= 1'b0;
            end
        end else if (!stall) begin
            // Stage 0: capture output of engine[0] (driven by raw data_in)
            stage_data[0]   <= encrypted[0];
            stage_seq_id[0] <= seq_id_in;
            stage_valid[0]  <= data_in_valid;

            // Stages 1 to ENCRYPT_LATENCY-1: propagate encrypted data
            for (int j = 1; j < ENCRYPT_LATENCY; j++) begin
                stage_data[j]   <= encrypted[j];
                stage_seq_id[j] <= stage_seq_id[j-1];
                stage_valid[j]  <= stage_valid[j-1];
            end
        end
        // When stall=1, all registers hold their current values implicitly.
    end

    // =========================================================================
    // Outputs: driven directly from the final pipeline register (stage 7)
    // =========================================================================
    assign data_out       = stage_data[ENCRYPT_LATENCY-1];
    assign data_out_valid = stage_valid[ENCRYPT_LATENCY-1];
    assign seq_id_out     = stage_seq_id[ENCRYPT_LATENCY-1];

endmodule
