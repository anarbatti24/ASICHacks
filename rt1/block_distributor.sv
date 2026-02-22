
module block_distributor #(
    parameter BLOCK_WIDTH = 32,
    parameter NUM_LANES = 4,
    parameter SEQUENCE_ID_WIDTH = 8
)(
    input  logic clk,
    input  logic rst_n,

    // Input Stream
    input  logic [BLOCK_WIDTH-1:0] data_in,
    input  logic data_in_valid,
    output logic data_in_ready,

    // Output to Lanes
    output logic [BLOCK_WIDTH-1:0] lane_data      [NUM_LANES-1:0],
    output logic [SEQUENCE_ID_WIDTH-1:0] lane_seq_id [NUM_LANES-1:0],
    output logic lane_valid     [NUM_LANES-1:0],
    input  logic lane_ready     [NUM_LANES-1:0]
);

    logic [$clog2(NUM_LANES)-1:0] lane_sel;
    logic [SEQUENCE_ID_WIDTH-1:0] seq_counter;

    integer i;

    // Ready logic
    assign data_in_ready = lane_ready[lane_sel];

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            lane_sel     <= 0;
            seq_counter  <= 0;

            for (i = 0; i < NUM_LANES; i++) begin
                lane_valid[i] <= 0;
            end
        end else begin

            // Default: clear all valids
            for (i = 0; i < NUM_LANES; i++) begin
                lane_valid[i] <= 0;
            end

            // On successful handshake
            if (data_in_valid && data_in_ready) begin

                lane_data[lane_sel]   <= data_in;
                lane_seq_id[lane_sel] <= seq_counter;
                lane_valid[lane_sel]  <= 1;

                seq_counter <= seq_counter + 1;
                lane_sel    <= lane_sel + 1;
            end
        end
    end

endmodule
