# Team Module Assignments

Quick reference for who owns which files during development.

## Person 1 — Encryption Lane Designer

### RTL Modules to Create
- `rtl/encrypt_engine.sv` - Core cipher logic (XOR + rotate)
- `rtl/encryption_lane.sv` - 8-stage pipeline wrapper

### Testbenches to Create
- `tb/encrypt_engine_tb.sv` - Test cipher correctness
- `tb/encryption_lane_tb.sv` - Test fixed latency and sequence ID propagation

### Success Criteria
- ✅ Exactly 8 cycles latency from input valid to output valid
- ✅ Sequence ID correctly propagated through pipeline
- ✅ Valid/ready handshake works correctly
- ✅ Can accept new block every cycle when downstream ready

### DEPS Targets
```bash
# Test your modules independently
simulate tb_encrypt_engine
simulate tb_encryption_lane
```

---

## Person 2 — Parallel Lane Replication + Scheduler

### RTL Modules to Create
- `rtl/block_distributor.sv` - Round-robin scheduler with sequence ID generation

### Testbenches to Create
- `tb/block_distributor_tb.sv` - Test distribution and sequence ID assignment

### Success Criteria
- ✅ Blocks distributed evenly across 4 lanes (round-robin)
- ✅ Sequence IDs increment monotonically (0, 1, 2, 3, ...)
- ✅ No blocks skipped or duplicated
- ✅ data_in_ready = lane_ready[selected_lane]
- ✅ Only one lane_valid[i] asserted at a time

### DEPS Targets
```bash
# Test your module independently
simulate tb_block_distributor
```

### Design Hints
```systemverilog
// Lane selection counter
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        lane_sel <= 0;
    else if (data_in_valid && data_in_ready)
        lane_sel <= (lane_sel + 1) % NUM_LANES;
end

// Sequence ID counter
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        seq_id <= 0;
    else if (data_in_valid && data_in_ready)
        seq_id <= seq_id + 1;
end
```

---

## Person 3 — Output Combiner + Flow Control

### RTL Modules to Create
- `rtl/output_combiner.sv` - Reorder buffer with sequence ID tracking

### Testbenches to Create
- `tb/output_combiner_tb.sv` - Test reordering with out-of-order inputs

### Success Criteria
- ✅ Outputs blocks in correct sequence order (0, 1, 2, 3, ...) regardless of arrival order
- ✅ Handles out-of-order completion (lane 2 finishes before lane 0)
- ✅ Buffers early-arriving blocks until predecessor completes
- ✅ Backpressure propagates correctly to lanes
- ✅ No blocks lost or duplicated

### DEPS Targets
```bash
# Test your module independently
simulate tb_output_combiner
```

### Design Hints
```systemverilog
// Track next expected sequence ID
logic [SEQUENCE_ID_WIDTH-1:0] next_seq_id;

// Reorder buffer (simple approach: one entry per lane)
logic [BLOCK_WIDTH-1:0] buffer_data [NUM_LANES-1:0];
logic [SEQUENCE_ID_WIDTH-1:0] buffer_seq_id [NUM_LANES-1:0];
logic buffer_valid [NUM_LANES-1:0];

// Each cycle, scan for block with next_seq_id
// Output it if found and downstream ready
// Increment next_seq_id when output occurs
```

---

## Person 4 — Top-Level Integration + Measurement + Demo

### RTL Modules to Create
- `rtl/crypto_accelerator_top.sv` - Top-level module integrating all components
- `rtl/performance_counter.sv` - Block and cycle counters

### Testbenches to Create
- `tb/crypto_accelerator_tb.sv` - System-level testbench
- `tb/performance_counter_tb.sv` - Counter verification

### Success Criteria
- ✅ All modules instantiated and connected correctly
- ✅ 1000-block streaming test passes
- ✅ Backpressure test passes
- ✅ Performance counters accurate
- ✅ No protocol violations (assertions pass)
- ✅ Waveforms show clean operation

### DEPS Targets
```bash
# Test performance counter
simulate tb_performance_counter

# System integration tests
simulate tb_crypto_accelerator_quick    # 100 blocks
simulate tb_crypto_accelerator_system   # 1000 blocks
```

### Integration Checklist

**crypto_accelerator_top.sv:**
- [ ] Instantiate `block_distributor`
- [ ] Instantiate 4× `encryption_lane` (use generate loop)
- [ ] Instantiate `output_combiner`
- [ ] Instantiate `performance_counter`
- [ ] Connect distributor → lanes (4 sets of signals)
- [ ] Connect lanes → combiner (4 sets of signals)
- [ ] Connect combiner → output
- [ ] Connect performance counter to combiner output
- [ ] Wire clock and reset to all modules

**crypto_accelerator_tb.sv:**
- [ ] Clock generation (100 MHz = 10ns period)
- [ ] Reset sequence (assert for 20ns)
- [ ] Input stimulus generator (1000 random blocks)
- [ ] Output checker (verify encryption correctness)
- [ ] Sequence checker (verify output order matches input order)
- [ ] Performance measurement (throughput calculation)
- [ ] Waveform dumping ($dumpfile, $dumpvars)
- [ ] Pass/fail reporting

---

## Module Dependencies

```
crypto_accelerator_top
    ├── block_distributor (Person 2)
    ├── encryption_lane (Person 1) × 4
    │   └── encrypt_engine (Person 1)
    ├── output_combiner (Person 3)
    └── performance_counter (Person 4)
```

## Day 2-3 Parallel Work (No Cross-Dependencies)

All four people can work **completely independently** during Day 2-3:

- **Person 1** needs NO files from others
- **Person 2** needs NO files from others
- **Person 3** needs NO files from others  
- **Person 4** creates skeleton files and testbench framework

This is possible because each person creates BOTH their module AND its testbench, allowing complete standalone verification.

## Day 4 Integration (Person 4 Leads)

**Person 4's Steps:**
1. Collect completed modules from Persons 1-3
2. Instantiate in `crypto_accelerator_top.sv`
3. Connect interfaces according to architecture spec Section 4
4. Run `simulate tb_crypto_accelerator_quick`
5. Debug with team when issues found
6. Iterate until basic 10-block test passes

**Everyone's Role:**
- Be available for debugging your module
- Help trace signals in waveforms
- Fix bugs in your module if found
- Communicate clearly about interface changes

---

## Quick Command Reference

```bash
# Check project structure
tree -L 2

# View individual targets in DEPS.yml
cat DEPS.yml

# Simulate individual module (Day 2-3)
simulate tb_encryption_lane        # Person 1
simulate tb_block_distributor      # Person 2
simulate tb_output_combiner        # Person 3
simulate tb_performance_counter    # Person 4

# Simulate system (Day 4-5)
simulate tb_crypto_accelerator_quick

# View waveforms
gtkwave sim/waveform.vcd           # or your preferred viewer

# Synthesize (Day 6)
synthesize dut_crypto_accelerator
```

---

## Communication Protocol

### Daily Standup (15 minutes)
1. What did you complete yesterday?
2. What are you working on today?
3. Any blockers or questions?

### Integration Day (Day 4)
- Be available for 4+ hours
- Have your module tested and working
- Bring waveforms showing your module working standalone
- Be ready to debug issues collaboratively

### Red Flags 🚩
- "My module works but I can't show a waveform" → NOT READY
- "I changed the interface" → NOTIFY TEAM IMMEDIATELY
- "I'm stuck and didn't ask for help" → ASK EARLY
- "I haven't tested it yet" → BLOCK INTEGRATION

---

**Questions? Check:**
1. Architecture spec: `docs/multi_lane_crypto_accelerator_architecture.md`
2. Project README: `PROJECT_README.md`
3. Your assigned section above
4. Ask team during standup
