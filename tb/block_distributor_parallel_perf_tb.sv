
`timescale 1ns/1ps

module block_distributor_parallel_perf_tb;

    // Parameters
    localparam BLOCK_WIDTH = 32;
    localparam NUM_LANES = 4;
    localparam SEQUENCE_ID_WIDTH = 8;
    localparam CLK_PERIOD = 10;
    localparam NUM_BLOCKS = 10000;  // 10K blocks (scale to 1M via math: x100)
    localparam LANE_PROCESSING_CYCLES = 10;  // Pipeline latency (NOT throughput bottleneck!)

    // DUT signals
    logic clock;
    logic reset;
    logic [BLOCK_WIDTH-1:0] data_in;
    logic data_in_valid;
    logic data_in_ready;
    logic [BLOCK_WIDTH-1:0] lane_data [NUM_LANES-1:0];
    logic [SEQUENCE_ID_WIDTH-1:0] lane_seq_id [NUM_LANES-1:0];
    logic lane_valid [NUM_LANES-1:0];
    logic lane_ready [NUM_LANES-1:0];

    // Pipelined lane processing simulation - each lane can accept 1 block/cycle
    // Pipeline: blocks enter and take LANE_PROCESSING_CYCLES to complete
    logic [BLOCK_WIDTH-1:0] lane_pipeline_data [NUM_LANES-1:0][LANE_PROCESSING_CYCLES-1:0];
    logic [SEQUENCE_ID_WIDTH-1:0] lane_pipeline_seq [NUM_LANES-1:0][LANE_PROCESSING_CYCLES-1:0];
    logic lane_pipeline_valid [NUM_LANES-1:0][LANE_PROCESSING_CYCLES-1:0];
    longint lane_blocks_accepted [NUM_LANES-1:0];
    longint lane_blocks_output [NUM_LANES-1:0];
    
    // Performance tracking
    longint start_time;
    longint end_time;
    longint total_cycles;
    longint blocks_sent;
    longint blocks_completed;  // Blocks completed by lanes
    real input_throughput;
    real aggregate_throughput;
    real avg_latency;
    
    // Error tracking
    integer error_count;
    integer i;

    // Instantiate DUT
    block_distributor #(
        .BLOCK_WIDTH(BLOCK_WIDTH),
        .NUM_LANES(NUM_LANES),
        .SEQUENCE_ID_WIDTH(SEQUENCE_ID_WIDTH)
    ) dut (
        .clk(clock),
        .rst_n(reset),
        .data_in(data_in),
        .data_in_valid(data_in_valid),
        .data_in_ready(data_in_ready),
        .lane_data(lane_data),
        .lane_seq_id(lane_seq_id),
        .lane_valid(lane_valid),
        .lane_ready(lane_ready)
    );

    // Clock generation
    initial begin
        clock = 0;
        forever #(CLK_PERIOD/2) clock = ~clock;
    end

    // Main test sequence
    initial begin
        $display("TEST START");
        $display("==========================================================");
        $display("BLOCK DISTRIBUTOR PARALLEL PERFORMANCE TEST");
        $display("Testing with %0d blocks across %0d parallel lanes", NUM_BLOCKS, NUM_LANES);
        $display("==========================================================");
        
        error_count = 0;
        blocks_sent = 0;
        blocks_completed = 0;

        // Initialize signals
        reset = 0;
        data_in = 0;
        data_in_valid = 0;
        for (i = 0; i < NUM_LANES; i++) begin
            lane_ready[i] = 1;  // Pipelined lanes always ready to accept
            lane_blocks_accepted[i] = 0;
            lane_blocks_output[i] = 0;
        end

        // Apply reset
        repeat(5) @(posedge clock);
        reset = 1;
        repeat(2) @(posedge clock);

        // Run performance test
        $display("\n[%0t] Starting parallel performance test...", $time);
        $display("Lane configuration: PIPELINED operation");
        $display("  - Throughput: 1 block/cycle per lane");
        $display("  - Latency: %0d cycles per block", LANE_PROCESSING_CYCLES);
        $display("  - Total lanes: %0d", NUM_LANES);
        $display("  - Expected aggregate: %0d blocks/cycle", NUM_LANES);
        performance_test();

        // Wait for all lanes to finish processing
        $display("[%0t] Waiting for all lanes to complete processing...", $time);
        wait_for_lanes_to_finish();

        // Calculate and display results
        repeat(10) @(posedge clock);
        display_results();
        
        if (error_count == 0) begin
            $display("\nTEST PASSED");
        end else begin
            $display("\nERROR");
            $error("TEST FAILED: %0d errors detected", error_count);
        end
        
        $finish;
    end

    // Performance test task - send blocks and let lanes process in parallel
    task performance_test();
        longint block_num;
        logic [BLOCK_WIDTH-1:0] test_data;
        
        // Record start time
        start_time = $time;
        
        // Send NUM_BLOCKS sequentially (lanes process in parallel)
        for (block_num = 0; block_num < NUM_BLOCKS; block_num++) begin
            // Generate test data
            test_data = block_num[BLOCK_WIDTH-1:0];
            
            // Send data
            data_in = test_data;
            data_in_valid = 1;
            
            // Wait for handshake
            @(posedge clock);
            while (!data_in_ready) begin
                @(posedge clock);
            end
            
            blocks_sent = blocks_sent + 1;
            
            // Progress indicator every 1k blocks
            if ((block_num > 0) && (block_num % 1000 == 0)) begin
                $display("[%0t] Progress: %0d blocks sent, %0d completed (%0.1f%%)", 
                         $time, blocks_sent, blocks_completed, (blocks_sent * 100.0) / NUM_BLOCKS);
            end
        end
        
        // Deassert valid after last block
        data_in_valid = 0;
        
        $display("[%0t] All blocks sent to distributor", $time);
    endtask

    // Wait for all lane pipeline processing to complete
    task wait_for_lanes_to_finish();
        integer timeout;
        integer pipeline_empty;
        integer j;
        
        timeout = 0;
        
        // Wait for all blocks to exit the pipeline (blocks_completed == blocks_sent)
        while (blocks_completed < blocks_sent && timeout < 50000) begin
            @(posedge clock);
            timeout = timeout + 1;
            
            // Progress update every 1000 cycles
            if (timeout % 1000 == 0) begin
                $display("[%0t] Waiting for pipeline drain: %0d/%0d blocks completed", 
                         $time, blocks_completed, blocks_sent);
            end
        end
        
        // Verify pipelines are empty
        pipeline_empty = 1;
        for (i = 0; i < NUM_LANES; i++) begin
            for (j = 0; j < LANE_PROCESSING_CYCLES; j++) begin
                if (lane_pipeline_valid[i][j]) begin
                    pipeline_empty = 0;
                end
            end
        end
        
        // Record end time after all processing completes
        end_time = $time;
        
        $display("[%0t] All lane processing completed", $time);
        $display("[%0t] Pipeline status: %s", $time, pipeline_empty ? "EMPTY" : "NOT EMPTY");
        $display("[%0t] Final blocks: sent=%0d, completed=%0d", $time, blocks_sent, blocks_completed);
    endtask

    // Simulate PIPELINED lane processing - each lane accepts 1 block/cycle
    // Models real crypto hardware with pipeline depth = LANE_PROCESSING_CYCLES
    always @(posedge clock) begin
        integer j;
        if (!reset) begin
            for (i = 0; i < NUM_LANES; i++) begin
                for (j = 0; j < LANE_PROCESSING_CYCLES; j++) begin
                    lane_pipeline_valid[i][j] <= 0;
                end
                lane_ready[i] <= 1;  // Always ready in pipelined design
            end
        end else begin
            for (i = 0; i < NUM_LANES; i++) begin
                // Pipeline shift: Move all stages forward
                for (j = LANE_PROCESSING_CYCLES-1; j > 0; j--) begin
                    lane_pipeline_data[i][j] <= lane_pipeline_data[i][j-1];
                    lane_pipeline_seq[i][j] <= lane_pipeline_seq[i][j-1];
                    lane_pipeline_valid[i][j] <= lane_pipeline_valid[i][j-1];
                end
                
                // Stage 0: Accept new block from distributor (every cycle if available)
                if (lane_valid[i] && lane_ready[i]) begin
                    lane_pipeline_data[i][0] <= lane_data[i];
                    lane_pipeline_seq[i][0] <= lane_seq_id[i];
                    lane_pipeline_valid[i][0] <= 1;
                    lane_blocks_accepted[i] <= lane_blocks_accepted[i] + 1;
                end else begin
                    lane_pipeline_valid[i][0] <= 0;  // Bubble in pipeline
                end
                
                // Output stage: Block completes after LANE_PROCESSING_CYCLES
                if (lane_pipeline_valid[i][LANE_PROCESSING_CYCLES-1]) begin
                    lane_blocks_output[i] <= lane_blocks_output[i] + 1;
                    blocks_completed <= blocks_completed + 1;
                end
            end
        end
    end

    // Display performance results
    task display_results();
        real sim_time_ns;
        real sim_time_us;
        real sim_time_ms;
        real parallel_speedup;
        
        total_cycles = (end_time - start_time) / CLK_PERIOD;
        sim_time_ns = end_time - start_time;
        sim_time_us = sim_time_ns / 1000.0;
        sim_time_ms = sim_time_us / 1000.0;
        
        if (total_cycles > 0) begin
            input_throughput = (blocks_sent * 1.0) / total_cycles;
            aggregate_throughput = (blocks_completed * 1.0) / total_cycles;
            avg_latency = (total_cycles * 1.0) / blocks_completed;
            parallel_speedup = aggregate_throughput / input_throughput;
        end else begin
            input_throughput = 0;
            aggregate_throughput = 0;
            avg_latency = 0;
            parallel_speedup = 0;
        end
        
        $display("\n==========================================================");
        $display("PARALLEL PERFORMANCE RESULTS");
        $display("==========================================================");
        $display("Blocks sent:               %0d", blocks_sent);
        $display("Blocks completed:          %0d", blocks_completed);
        $display("Total cycles:              %0d", total_cycles);
        $display("Simulation time:           %0.2f ns (%0.2f us, %0.2f ms)", 
                 sim_time_ns, sim_time_us, sim_time_ms);
        $display("----------------------------------------------------------");
        $display("INPUT PERFORMANCE:");
        $display("  Input throughput:        %0.4f blocks/cycle", input_throughput);
        $display("  Input data rate:         %0.2f Mblocks/sec", input_throughput * (1000.0/CLK_PERIOD));
        $display("----------------------------------------------------------");
        $display("AGGREGATE PARALLEL PERFORMANCE:");
        $display("  Aggregate throughput:    %0.4f blocks/cycle", aggregate_throughput);
        $display("  Aggregate data rate:     %0.2f Mblocks/sec", aggregate_throughput * (1000.0/CLK_PERIOD));
        $display("  Parallel speedup:        %0.2fx", parallel_speedup);
        $display("  Average latency:         %0.2f cycles/block", avg_latency);
        $display("----------------------------------------------------------");
        $display("CONFIGURATION:");
        $display("  Number of lanes:         %0d", NUM_LANES);
        $display("  Block width:             %0d bits", BLOCK_WIDTH);
        $display("  Lane processing cycles:  %0d", LANE_PROCESSING_CYCLES);
        $display("  Clock frequency:         %0d MHz", 1000/CLK_PERIOD);
        $display("----------------------------------------------------------");
        $display("SCALING TO 1M BLOCKS:");
        $display("  Estimated time:          %0.2f ms", sim_time_ms * 100.0);
        $display("  Throughput at 1M:        %0.2f Mblocks/sec", aggregate_throughput * (1000.0/CLK_PERIOD));
        $display("==========================================================");
        
        // Verification check
        if (blocks_sent != NUM_BLOCKS) begin
            error_count = error_count + 1;
            $display("LOG: %0t : ERROR : block_distributor_parallel_perf_tb : blocks_sent : expected_value: %0d actual_value: %0d", 
                     $time, NUM_BLOCKS, blocks_sent);
        end else begin
            $display("LOG: %0t : INFO : block_distributor_parallel_perf_tb : blocks_sent : expected_value: %0d actual_value: %0d", 
                     $time, NUM_BLOCKS, blocks_sent);
        end
        
        if (blocks_completed != NUM_BLOCKS) begin
            error_count = error_count + 1;
            $display("LOG: %0t : ERROR : block_distributor_parallel_perf_tb : blocks_completed : expected_value: %0d actual_value: %0d", 
                     $time, NUM_BLOCKS, blocks_completed);
        end else begin
            $display("LOG: %0t : INFO : block_distributor_parallel_perf_tb : blocks_completed : expected_value: %0d actual_value: %0d", 
                     $time, NUM_BLOCKS, blocks_completed);
        end
        
        $display("\nTotal errors detected: %0d\n", error_count);
    endtask

    // Waveform dump
    initial begin
        $dumpfile("dumpfile.fst");
        $dumpvars(0);
    end

    // Timeout watchdog
    initial begin
        #10000000;  // 10ms timeout (enough for 10K blocks with 10-cycle processing)
        $display("ERROR");
        $fatal(1, "Simulation timeout!");
    end

endmodule
