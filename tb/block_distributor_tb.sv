
`timescale 1ns/1ps

module block_distributor_tb;

    // Parameters
    localparam BLOCK_WIDTH = 32;
    localparam NUM_LANES = 4;
    localparam SEQUENCE_ID_WIDTH = 8;
    localparam CLK_PERIOD = 10;

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

    // Test control signals
    integer i;
    integer error_count;
    integer test_count;

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
        error_count = 0;
        test_count = 0;

        // Initialize signals
        reset = 0;
        data_in = 0;
        data_in_valid = 0;
        for (i = 0; i < NUM_LANES; i++) begin
            lane_ready[i] = 0;
        end

        // Apply reset
        repeat(5) @(posedge clock);
        reset = 1;
        @(posedge clock);

        // Test 1: Basic round-robin distribution with all lanes ready
        $display("=== Test 1: Basic Round-Robin Distribution ===");
        test_basic_round_robin();

        // Test 2: Backpressure - one lane not ready
        $display("=== Test 2: Lane Backpressure ===");
        test_lane_backpressure();

        // Test 3: Sequential lane ready assertion
        $display("=== Test 3: Sequential Lane Ready ===");
        test_sequential_ready();

        // Test 4: Sequence ID verification
        $display("=== Test 4: Sequence ID Increment ===");
        test_sequence_id();

        // Test 5: Reset during operation
        $display("=== Test 5: Reset During Operation ===");
        test_reset_behavior();

        // Final results
        repeat(10) @(posedge clock);
        
        if (error_count == 0) begin
            $display("TEST PASSED");
        end else begin
            $display("ERROR");
            $error("TEST FAILED: %0d errors out of %0d tests", error_count, test_count);
        end
        
        $finish(0);
    end

    // Test 1: Basic round-robin distribution
    task test_basic_round_robin();
        integer txn_num;
        integer check_lane;
        logic [BLOCK_WIDTH-1:0] expected_data [NUM_LANES-1:0];
        logic [SEQUENCE_ID_WIDTH-1:0] start_seq;
        
        // All lanes ready
        for (i = 0; i < NUM_LANES; i++) begin
            lane_ready[i] = 1;
        end
        
        //  Send NUM_LANES transactions to fill all lanes
        for (txn_num = 0; txn_num < NUM_LANES; txn_num++) begin
            expected_data[txn_num] = 32'hA000_0000 + txn_num;
            data_in = expected_data[txn_num];
            data_in_valid = 1;
            
            @(posedge clock); // Handshake happens
            data_in_valid = 0;
        end
        
        // Wait a cycle for last transaction to settle
        @(posedge clock);
        #1;
        
        // Now check all lanes received correct data
        for (check_lane = 0; check_lane < NUM_LANES; check_lane++) begin
            test_count = test_count + 1;
            if (lane_data[check_lane] !== expected_data[check_lane]) begin
                error_count = error_count + 1;
                $display("LOG: %0t : ERROR : block_distributor_tb : dut.lane_data[%0d] : expected_value: 32'h%08h actual_value: 32'h%08h", 
                         $time, check_lane, expected_data[check_lane], lane_data[check_lane]);
            end else begin
                $display("LOG: %0t : INFO : block_distributor_tb : dut.lane_data[%0d] : expected_value: 32'h%08h actual_value: 32'h%08h", 
                         $time, check_lane, expected_data[check_lane], lane_data[check_lane]);
            end
        end
        
        // Check sequence IDs (should be 0, 1, 2, 3)
        for (check_lane = 0; check_lane < NUM_LANES; check_lane++) begin
            test_count = test_count + 1;
            if (lane_seq_id[check_lane] !== check_lane) begin
                error_count = error_count + 1;
                $display("LOG: %0t : ERROR : block_distributor_tb : dut.lane_seq_id[%0d] : expected_value: 8'h%02h actual_value: 8'h%02h", 
                         $time, check_lane, check_lane[7:0], lane_seq_id[check_lane]);
            end else begin
                $display("LOG: %0t : INFO : block_distributor_tb : dut.lane_seq_id[%0d] : expected_value: 8'h%02h actual_value: 8'h%02h", 
                         $time, check_lane, check_lane[7:0], lane_seq_id[check_lane]);
            end
        end
        
        data_in_valid = 0;
        @(posedge clock);
    endtask

    // Test 2: Backpressure from one lane
    task test_lane_backpressure();
        // Set lane 2 not ready
        lane_ready[0] = 1;
        lane_ready[1] = 1;
        lane_ready[2] = 0;  // Not ready
        lane_ready[3] = 1;
        
        // Send data - should distribute to lanes 0, 1, then stall at lane 2
        data_in = 32'hBEEF_0000;
        data_in_valid = 1;
        @(posedge clock);
        data_in_valid = 0;
        @(posedge clock);
        
        data_in = 32'hBEEF_0001;
        data_in_valid = 1;
        @(posedge clock);
        data_in_valid = 0;
        @(posedge clock);
        
        // Now should stall because lane 2 is not ready
        data_in = 32'hBEEF_0002;
        data_in_valid = 1;
        @(posedge clock);
        #1;
        
        test_count = test_count + 1;
        if (data_in_ready !== 1'b0) begin
            error_count = error_count + 1;
            $display("LOG: %0t : ERROR : block_distributor_tb : dut.data_in_ready : expected_value: 1'b0 actual_value: %0b", 
                     $time, data_in_ready);
        end else begin
            $display("LOG: %0t : INFO : block_distributor_tb : dut.data_in_ready : expected_value: 1'b0 actual_value: %0b", 
                     $time, data_in_ready);
        end
        
        // Make lane 2 ready
        lane_ready[2] = 1;
        #1;
        
        test_count = test_count + 1;
        if (data_in_ready !== 1'b1) begin
            error_count = error_count + 1;
            $display("LOG: %0t : ERROR : block_distributor_tb : dut.data_in_ready : expected_value: 1'b1 actual_value: %0b", 
                     $time, data_in_ready);
        end else begin
            $display("LOG: %0t : INFO : block_distributor_tb : dut.data_in_ready : expected_value: 1'b1 actual_value: %0b", 
                     $time, data_in_ready);
        end
        
        @(posedge clock);
        data_in_valid = 0;
        @(posedge clock);
    endtask

    // Test 3: Test backpressure behavior more thoroughly
    task test_sequential_ready();
        integer trans_count;
        logic ready_state;
        
        // Set all lanes ready
        for (i = 0; i < NUM_LANES; i++) begin
            lane_ready[i] = 1;
        end
        
        // Send a couple of transactions with all lanes ready - should succeed quickly
        for (trans_count = 0; trans_count < 2; trans_count++) begin
            data_in = 32'hCAFE_0000 + trans_count;
            data_in_valid = 1;
            @(posedge clock);
            ready_state = data_in_ready;
            data_in_valid = 0;
            
            test_count = test_count + 1;
            if (ready_state !== 1'b1) begin
                error_count = error_count + 1;
                $display("LOG: %0t : ERROR : block_distributor_tb : dut.data_in_ready : expected_value: 1'b1 actual_value: %0b", 
                         $time, ready_state);
            end else begin
                $display("LOG: %0t : INFO : block_distributor_tb : dut.data_in_ready : expected_value: 1'b1 actual_value: %0b", 
                         $time, ready_state);
            end
        end
        
        @(posedge clock);
    endtask

    // Test 4: Sequence ID increment verification - send enough transactions to fill all lanes twice
    task test_sequence_id();
        logic [SEQUENCE_ID_WIDTH-1:0] seq_ids [NUM_LANES-1:0];
        integer j;
        integer check_lane;
        
        for (i = 0; i < NUM_LANES; i++) begin
            lane_ready[i] = 1;
        end
        
        // Send 2*NUM_LANES transactions to ensure all lanes get fresh data
        for (j = 0; j < (2*NUM_LANES); j++) begin
            data_in = 32'hDEAD_0000 + j;
            data_in_valid = 1;
            @(posedge clock);
            data_in_valid = 0;
        end
        
        // Wait for all transactions to complete
        @(posedge clock);
        #1;
        
        // Store all sequence IDs
        for (check_lane = 0; check_lane < NUM_LANES; check_lane++) begin
            seq_ids[check_lane] = lane_seq_id[check_lane];
        end
        
        // Verify consecutive lanes increment by 1 (allowing for wraparound)
        test_count = test_count + 1;
        if (lane_seq_id[1] !== (seq_ids[0] + 1)) begin
            error_count = error_count + 1;
            $display("LOG: %0t : ERROR : block_distributor_tb : dut.lane_seq_id[1] vs [0] : expected_value: 8'h%02h actual_value: 8'h%02h", 
                     $time, seq_ids[0] + 1, lane_seq_id[1]);
        end else begin
            $display("LOG: %0t : INFO : block_distributor_tb : dut.lane_seq_id[1] vs [0] : expected_value: 8'h%02h actual_value: 8'h%02h", 
                     $time, seq_ids[0] + 1, lane_seq_id[1]);
        end
        
        test_count = test_count + 1;
        if (lane_seq_id[2] !== (seq_ids[1] + 1)) begin
            error_count = error_count + 1;
            $display("LOG: %0t : ERROR : block_distributor_tb : dut.lane_seq_id[2] vs [1] : expected_value: 8'h%02h actual_value: 8'h%02h", 
                     $time, seq_ids[1] + 1, lane_seq_id[2]);
        end else begin
            $display("LOG: %0t : INFO : block_distributor_tb : dut.lane_seq_id[2] vs [1] : expected_value: 8'h%02h actual_value: 8'h%02h", 
                     $time, seq_ids[1] + 1, lane_seq_id[2]);
        end
        
        test_count = test_count + 1;
        if (lane_seq_id[3] !== (seq_ids[2] + 1)) begin
            error_count = error_count + 1;
            $display("LOG: %0t : ERROR : block_distributor_tb : dut.lane_seq_id[3] vs [2] : expected_value: 8'h%02h actual_value: 8'h%02h", 
                     $time, seq_ids[2] + 1, lane_seq_id[3]);
        end else begin
            $display("LOG: %0t : INFO : block_distributor_tb : dut.lane_seq_id[3] vs [2] : expected_value: 8'h%02h actual_value: 8'h%02h", 
                     $time, seq_ids[2] + 1, lane_seq_id[3]);
        end
        
        data_in_valid = 0;
        @(posedge clock);
    endtask

    // Test 5: Reset behavior
    task test_reset_behavior();
        // Send some data
        for (i = 0; i < NUM_LANES; i++) begin
            lane_ready[i] = 1;
        end
        
        data_in = 32'h1234_5678;
        data_in_valid = 1;
        @(posedge clock);
        data_in_valid = 0;
        @(posedge clock);
        
        // Apply reset
        reset = 0;
        data_in_valid = 0;
        repeat(3) @(posedge clock);
        #1;
        
        // Check all lane_valid are cleared (they should be 0 during reset)
        for (i = 0; i < NUM_LANES; i++) begin
            test_count = test_count + 1;
            if (lane_valid[i] !== 1'b0) begin
                error_count = error_count + 1;
                $display("LOG: %0t : ERROR : block_distributor_tb : dut.lane_valid[%0d] : expected_value: 1'b0 actual_value: %0b", 
                         $time, i, lane_valid[i]);
            end else begin
                $display("LOG: %0t : INFO : block_distributor_tb : dut.lane_valid[%0d] : expected_value: 1'b0 actual_value: %0b", 
                         $time, i, lane_valid[i]);
            end
        end
        
        reset = 1;
        @(posedge clock);
    endtask

    // Waveform dump
    initial begin
        $dumpfile("dumpfile.fst");
        $dumpvars(0);
    end

    // Timeout watchdog
    initial begin
        #100000;
        $display("ERROR");
        $fatal(1, "Simulation timeout!");
    end

endmodule
