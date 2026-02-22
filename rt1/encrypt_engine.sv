// =============================================================================
// encrypt_engine.sv
// 
// Simple encryption engine - ONE round of encryption
// Performs: XOR with key, then rotate left by 1 bit
//
// Author: Person 1 (Encryption Lane Designer)
// =============================================================================

module encrypt_engine #(
    parameter BLOCK_WIDTH = 32
) (
    input  logic [BLOCK_WIDTH-1:0]  data_in,      // Input plaintext
    input  logic [BLOCK_WIDTH-1:0]  round_key,    // Round key for XOR
    output logic [BLOCK_WIDTH-1:0]  data_out      // Output ciphertext
);



    logic [BLOCK_WIDTH-1:0] xor_result;
    assign xor_result = data_in ^ round_key;
    

    assign data_out = {xor_result[BLOCK_WIDTH-2:0], xor_result[BLOCK_WIDTH-1]};

endmodule
