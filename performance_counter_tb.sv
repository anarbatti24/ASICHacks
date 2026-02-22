// =============================================================================
// performance_counter_tb.sv
// 
// Testbench for performance_counter module
// Tests block counting and cycle counting
//
// Author: Person 4 (Top-Level Integration + Measurement)
// =============================================================================

module performance_counter_tb;

    // Parameters
    localparam COUNTER_WIDTH = 32;
    localparam CLK_PERIOD = 10;  // 10ns = 100 MHz
    
    // DUT signals
    logic                       clk;
    logic                       rst_n;
    logic                       block_completed;
    logic [COUNTER_WIDTH-1:0]   blocks_processed;
    logic [COUNTER_WIDTH-1:0]   cycles_elapsed;
    
    // DUT instantiation
    performance_counter #(
        .COUNTER_WIDTH(COUNTER_WIDTH)
    ) dut (
        .clk                (clk),
        .rst_n              (rst_n),
        .block_completed    (block_completed),
        .blocks_processed   (blocks_processed),
        .cycles_elapsed     (cycles_elapsed)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Test stimulus
    initial begin
        // Variable declarations
        logic [COUNTER_WIDTH-1:0] prev_cycles;
        logic [COUNTER_WIDTH-1:0] start_blocks;
        
        // Initialize signals
        rst_n = 0;
        block_completed = 0;
        
        // Reset sequence
        repeat(2) @(posedge clk);
        rst_n = 1;
        @(posedge clk);
        
        // Test 1: Verify counters start at zero
        $display("Test 1: Reset verification");
        if (blocks_processed == 0 && cycles_elapsed == 0) begin
            $display("  PASS: Counters reset to zero");
        end else begin
            $display("  FAIL: Counters not zero after reset");
            $display("    blocks_processed = %0d, cycles_elapsed = %0d", blocks_processed, cycles_elapsed);
        end
        
        // Test 2: Count 10 blocks
        $display("\nTest 2: Count 10 blocks");
        repeat(10) begin
            @(posedge clk);
            block_completed = 1;
            @(posedge clk);
            block_completed = 0;
            repeat(3) @(posedge clk);  // Idle cycles between blocks
        end
        
        @(posedge clk);
        if (blocks_processed == 10) begin
            $display("  PASS: Block counter = %0d", blocks_processed);
        end else begin
            $display("  FAIL: Expected 10, got %0d", blocks_processed);
        end
        
        // Test 3: Verify cycle counter is free-running
        $display("\nTest 3: Cycle counter verification");
        prev_cycles = cycles_elapsed;
        repeat(100) @(posedge clk);
        
        if (cycles_elapsed == prev_cycles + 100) begin
            $display("  PASS: Cycle counter incremented correctly (%0d cycles)", cycles_elapsed);
        end else begin
            $display("  FAIL: Expected %0d cycles, got %0d", prev_cycles + 100, cycles_elapsed);
        end
        
        // Test 4: Continuous block completion
        $display("\nTest 4: Continuous block completion");
        start_blocks = blocks_processed;
        block_completed = 1;
        repeat(20) @(posedge clk);
        block_completed = 0;
        @(posedge clk);
        
        if (blocks_processed == start_blocks + 20) begin
            $display("  PASS: Continuous counting works (%0d blocks)", blocks_processed);
        end else begin
            $display("  FAIL: Expected %0d, got %0d", start_blocks + 20, blocks_processed);
        end
        
        // Summary
        $display("\n========================================");
        $display("Performance Counter Testbench Complete");
        $display("Total Blocks Processed: %0d", blocks_processed);
        $display("Total Cycles Elapsed: %0d", cycles_elapsed);
        $display("========================================\n");
        
        $finish;
    end
    
    // Waveform dumping
    initial begin
        $dumpfile("performance_counter_tb.vcd");
        $dumpvars(0, performance_counter_tb);
    end

endmodule
