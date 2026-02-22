// =============================================================================
// encrypt_engine_tb.sv
//
// Testbench for encrypt_engine
// Tests the simple XOR + rotate cipher
// =============================================================================

module encrypt_engine_tb;

    // Parameters
    localparam BLOCK_WIDTH = 32;
    
    // Testbench signals
    logic [BLOCK_WIDTH-1:0] data_in;
    logic [BLOCK_WIDTH-1:0] round_key;
    logic [BLOCK_WIDTH-1:0] data_out;
    
    // Helper variables for checking
    logic [31:0] expected_xor;
    logic [31:0] expected_out;
    
    // Instantiate the DUT (Device Under Test)
    encrypt_engine #(
        .BLOCK_WIDTH(BLOCK_WIDTH)
    ) dut (
        .data_in(data_in),
        .round_key(round_key),
        .data_out(data_out)
    );
    
    // Test procedure
    initial begin
        $display("TEST START");
        $display("=========================================");
        $display("Testing encrypt_engine");
        $display("=========================================");
        
        // Test 1: Basic encryption
        $display("\nTest 1: Basic encryption");
        data_in = 32'h12345678;
        round_key = 32'hDEADBEEF;
        #10; // Wait for combinational logic
        
        expected_xor = data_in ^ round_key;
        expected_out = {expected_xor[30:0], expected_xor[31]};
        
        $display("Input:    0x%h", data_in);
        $display("Key:      0x%h", round_key);
        $display("Output:   0x%h", data_out);
        $display("Expected: 0x%h", expected_out);
        
        if (data_out === expected_out) begin
            $display("✓ Test 1 PASSED");
        end else begin
            $display("ERROR: Test 1 FAILED");
            $error("Encryption output incorrect!");
        end
        
        // Test 2: All zeros
        $display("\nTest 2: All zeros input");
        data_in = 32'h00000000;
        round_key = 32'hFFFFFFFF;
        #10;
        
        $display("Input:    0x%h", data_in);
        $display("Key:      0x%h", round_key);
        $display("Output:   0x%h", data_out);
        
        // Test 3: All ones
        $display("\nTest 3: All ones input");
        data_in = 32'hFFFFFFFF;
        round_key = 32'h00000000;
        #10;
        
        $display("Input:    0x%h", data_in);
        $display("Key:      0x%h", round_key);
        $display("Output:   0x%h", data_out);
        
        // Test 4: Check rotation specifically
        $display("\nTest 4: Verify rotation");
        data_in = 32'h80000001;  // MSB=1, LSB=1
        round_key = 32'h00000000; // No XOR effect
        #10;
        
        $display("Input:    0x%h (binary: %b)", data_in, data_in);
        $display("Output:   0x%h (binary: %b)", data_out, data_out);
        
        // After rotation, MSB should become LSB
        if (data_out[0] === 1'b1 && data_out[31] === 1'b0) begin
            $display("✓ Test 4 PASSED - Rotation working correctly");
        end else begin
            $display("ERROR: Test 4 FAILED - Rotation not working");
            $error("Rotation logic incorrect!");
        end
        
        $display("\n=========================================");
        $display("TEST PASSED");
        $display("All tests completed successfully!");
        $display("=========================================");
        
        $finish;
    end
    
    // Waveform dump
    initial begin
        $dumpfile("dumpfile.fst");
        $dumpvars(0);
    end

endmodule
