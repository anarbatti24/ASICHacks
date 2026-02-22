// =============================================================================
// crypto_accelerator_tb.sv
// 
// System-level testbench for crypto_accelerator_top
// Tests 1000-block streaming, backpressure, and performance measurement
//
// Author: Person 4 (Top-Level Integration + Demo)
// =============================================================================

module crypto_accelerator_tb;

    // Parameters
    localparam BLOCK_WIDTH = 32;
    localparam NUM_LANES = 4;
    localparam ENCRYPT_LATENCY = 8;
    localparam COUNTER_WIDTH = 32;
    localparam CLK_PERIOD = 10;  // 10ns = 100 MHz
    localparam NUM_TEST_BLOCKS = 1000;
    
    // DUT signals
    logic                       clk;
    logic                       rst_n;
    logic [BLOCK_WIDTH-1:0]     data_in;
    logic                       data_in_valid;
    logic                       data_in_ready;
    logic [BLOCK_WIDTH-1:0]     data_out;
    logic                       data_out_valid;
    logic                       data_out_ready;
    logic [COUNTER_WIDTH-1:0]   blocks_processed;
    logic [COUNTER_WIDTH-1:0]   cycles_elapsed;
    
    // Test variables
    logic [BLOCK_WIDTH-1:0]     input_data_queue[$];
    logic [BLOCK_WIDTH-1:0]     expected_output_queue[$];
    logic [BLOCK_WIDTH-1:0]     received_output_queue[$];
    int                         blocks_sent = 0;
    int                         blocks_received = 0;
    int                         errors = 0;
    
    // DUT instantiation
    crypto_accelerator_top #(
        .BLOCK_WIDTH        (BLOCK_WIDTH),
        .NUM_LANES          (NUM_LANES),
        .ENCRYPT_LATENCY    (ENCRYPT_LATENCY),
        .COUNTER_WIDTH      (COUNTER_WIDTH)
    ) dut (
        .clk                (clk),
        .rst_n              (rst_n),
        .data_in            (data_in),
        .data_in_valid      (data_in_valid),
        .data_in_ready      (data_in_ready),
        .data_out           (data_out),
        .data_out_valid     (data_out_valid),
        .data_out_ready     (data_out_ready),
        .blocks_processed   (blocks_processed),
        .cycles_elapsed     (cycles_elapsed)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Simple encryption function for verification
    // Must match encrypt_engine implementation: XOR + rotate left
    function automatic logic [BLOCK_WIDTH-1:0] encrypt_block(
        input logic [BLOCK_WIDTH-1:0] plaintext,
        input logic [BLOCK_WIDTH-1:0] round_key
    );
        logic [BLOCK_WIDTH-1:0] xor_result;
        xor_result = plaintext ^ round_key;
        // Rotate left by 1 bit
        return {xor_result[BLOCK_WIDTH-2:0], xor_result[BLOCK_WIDTH-1]};
    endfunction
    
    // Generate expected encrypted output
    // For ENCRYPT_LATENCY=8 rounds, apply encryption 8 times with different keys
    function automatic logic [BLOCK_WIDTH-1:0] multi_round_encrypt(
        input logic [BLOCK_WIDTH-1:0] plaintext
    );
        logic [BLOCK_WIDTH-1:0] temp;
        logic [BLOCK_WIDTH-1:0] round_key;
        temp = plaintext;
        for (int round = 0; round < ENCRYPT_LATENCY; round++) begin
            round_key = 32'hDEADBEEF ^ (round << 24);  // Simple key schedule
            temp = encrypt_block(temp, round_key);
        end
        return temp;
    endfunction
    
    // Input stimulus generator
    initial begin
        // Initialize
        rst_n = 0;
        data_in = 0;
        data_in_valid = 0;
        data_out_ready = 1;  // Always ready for now (can add backpressure later)
        
        // Reset sequence
        repeat(5) @(posedge clk);
        rst_n = 1;
        @(posedge clk);
        
        $display("========================================");
        $display("Starting System Test: %0d blocks", NUM_TEST_BLOCKS);
        $display("========================================\n");
        
        // Generate and send test blocks
        for (int i = 0; i < NUM_TEST_BLOCKS; i++) begin
            logic [BLOCK_WIDTH-1:0] test_data;
            logic [BLOCK_WIDTH-1:0] expected;
            
            // Generate pseudo-random test data
            test_data = $random;
            
            // Calculate expected encrypted output
            expected = multi_round_encrypt(test_data);
            
            // Store for verification
            input_data_queue.push_back(test_data);
            expected_output_queue.push_back(expected);
            
            // Send to DUT
            @(posedge clk);
            data_in = test_data;
            data_in_valid = 1;
            
            // Wait for ready
            while (!data_in_ready) @(posedge clk);
            
            blocks_sent++;
            
            if (blocks_sent % 100 == 0) begin
                $display("Sent %0d blocks...", blocks_sent);
            end
        end
        
        // Deassert valid
        @(posedge clk);
        data_in_valid = 0;
        
        $display("All %0d blocks sent\n", blocks_sent);
    end
    
    // Output monitor and checker
    initial begin
        // Variable declarations
        logic [BLOCK_WIDTH-1:0] expected;
        real throughput;
        
        // Wait for reset
        wait (rst_n == 1);
        
        // Monitor outputs
        forever begin
            @(posedge clk);
            if (data_out_valid && data_out_ready) begin
                // Get expected value
                expected = expected_output_queue.pop_front();
                received_output_queue.push_back(data_out);
                blocks_received++;
                
                // Verify correctness
                if (data_out !== expected) begin
                    $display("ERROR: Block %0d mismatch!", blocks_received);
                    $display("  Expected: 0x%08h", expected);
                    $display("  Received: 0x%08h", data_out);
                    errors++;
                end else if (blocks_received % 100 == 0) begin
                    $display("Received %0d blocks correctly...", blocks_received);
                end
                
                // Check if done
                if (blocks_received == NUM_TEST_BLOCKS) begin
                    repeat(10) @(posedge clk);
                    
                    // Final report
                    $display("\n========================================");
                    $display("TEST COMPLETE");
                    $display("========================================");
                    $display("Blocks Sent:      %0d", blocks_sent);
                    $display("Blocks Received:  %0d", blocks_received);
                    $display("Blocks Processed: %0d (HW counter)", blocks_processed);
                    $display("Cycles Elapsed:   %0d", cycles_elapsed);
                    $display("Errors:           %0d", errors);
                    
                    if (errors == 0 && blocks_received == NUM_TEST_BLOCKS) begin
                        $display("\n*** ALL TESTS PASSED ***\n");
                    end else begin
                        $display("\n*** TEST FAILED ***\n");
                    end
                    
                    // Calculate throughput
                    throughput = (real'(blocks_processed) / real'(cycles_elapsed)) * NUM_LANES;
                    $display("Throughput: %.3f blocks/cycle", throughput);
                    $display("Theoretical Max: %.3f blocks/cycle", real'(NUM_LANES) / real'(ENCRYPT_LATENCY));
                    $display("========================================\n");
                    
                    $finish;
                end
            end
        end
    end
    
    // Timeout watchdog
    initial begin
        #(CLK_PERIOD * 100000);  // 100k cycles timeout
        $display("\nERROR: Simulation timeout!");
        $display("Blocks sent: %0d, Blocks received: %0d", blocks_sent, blocks_received);
        $finish;
    end
    
    // Waveform dumping
    initial begin
        $dumpfile("crypto_accelerator_tb.vcd");
        $dumpvars(0, crypto_accelerator_tb);
    end

endmodule
