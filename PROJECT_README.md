# Multi-Lane Streaming Crypto Accelerator

**4-lane parallel streaming encryption accelerator ASIC design**

## Project Overview

This project implements a streaming crypto accelerator with 4 parallel encryption lanes, demonstrating:
- Parallel datapath architecture
- Streaming design with valid/ready flow control
- Performance measurement and scaling
- Industry-style accelerator IP design

## Team Structure

| Person | Role | Modules | Testbenches |
|--------|------|---------|-------------|
| **Person 1** | Encryption Lane Designer | `encryption_lane.sv`<br>`encrypt_engine.sv` | `encryption_lane_tb.sv`<br>`encrypt_engine_tb.sv` |
| **Person 2** | Distributor & Scheduler | `block_distributor.sv` | `block_distributor_tb.sv` |
| **Person 3** | Combiner & Flow Control | `output_combiner.sv` | `output_combiner_tb.sv` |
| **Person 4** | Integration & Measurement | `crypto_accelerator_top.sv`<br>`performance_counter.sv` | `crypto_accelerator_tb.sv`<br>`performance_counter_tb.sv` |

## Directory Structure

```
.
├── rtl/                          # RTL source files
│   ├── crypto_accelerator_top.sv       # Top-level integration (Person 4)
│   ├── block_distributor.sv            # Round-robin distributor (Person 2)
│   ├── encryption_lane.sv              # Single encryption lane (Person 1)
│   ├── encrypt_engine.sv               # Core cipher logic (Person 1)
│   ├── output_combiner.sv              # Reorder buffer (Person 3)
│   └── performance_counter.sv          # Statistics (Person 4)
│
├── tb/                           # Testbench files
│   ├── crypto_accelerator_tb.sv        # System testbench (Person 4)
│   ├── block_distributor_tb.sv         # Distributor test (Person 2)
│   ├── encryption_lane_tb.sv           # Lane test (Person 1)
│   ├── encrypt_engine_tb.sv            # Engine test (Person 1)
│   ├── output_combiner_tb.sv           # Combiner test (Person 3)
│   └── performance_counter_tb.sv       # Counter test (Person 4)
│
├── sim/                          # Simulation outputs (waveforms, logs)
├── syn/                          # Synthesis scripts and reports
├── docs/                         # Documentation
│   └── multi_lane_crypto_accelerator_architecture.md
│
├── DEPS.yml                      # Dependency and build configuration
└── PROJECT_README.md             # This file
```

## Design Parameters (LOCKED - Do Not Change Without Team Agreement)

| Parameter | Value | Description |
|-----------|-------|-------------|
| `BLOCK_WIDTH` | 32 bits | Data width for all blocks |
| `NUM_LANES` | 4 | Number of parallel encryption lanes |
| `ENCRYPT_LATENCY` | 8 cycles | Fixed latency per encryption |
| `SEQUENCE_ID_WIDTH` | 8 bits | Width of sequence tracking |
| `COUNTER_WIDTH` | 32 bits | Performance counter width |

**⚠️ These parameters must be agreed upon in Day 1 meeting before coding starts!**

## Workflow Timeline

### **Day 1: Architecture Lockdown** (CRITICAL)
- [ ] All team members read architecture specification
- [ ] Review and sign off on design parameters
- [ ] Draw complete signal-level block diagram together
- [ ] Agree on interface definitions
- [ ] Assign module ownership

### **Day 2-3: Independent Module Development**
Each person develops and tests their assigned modules independently:

**Person 1:**
- [ ] Implement `encrypt_engine.sv` (simple XOR + rotate cipher)
- [ ] Implement `encryption_lane.sv` (8-stage pipeline)
- [ ] Create `encrypt_engine_tb.sv`
- [ ] Create `encryption_lane_tb.sv`
- [ ] Verify fixed 8-cycle latency
- [ ] Verify sequence ID propagation

**Person 2:**
- [ ] Implement `block_distributor.sv` (round-robin scheduler)
- [ ] Create sequence ID generator
- [ ] Create `block_distributor_tb.sv`
- [ ] Test with 4 dummy lanes (always ready)
- [ ] Verify even distribution across lanes

**Person 3:**
- [ ] Implement `output_combiner.sv` (reorder buffer)
- [ ] Create next-sequence-ID tracker
- [ ] Create `output_combiner_tb.sv`
- [ ] Inject out-of-order test blocks
- [ ] Verify correct output ordering

**Person 4:**
- [ ] Implement `performance_counter.sv`
- [ ] Create `crypto_accelerator_top.sv` skeleton
- [ ] Create `crypto_accelerator_tb.sv` framework
- [ ] Set up simulation environment
- [ ] Prepare waveform viewing tools

### **Day 4: First Integration**
- [ ] Person 4 instantiates all modules in top-level
- [ ] Connect all interfaces
- [ ] Run simple 10-block test
- [ ] Debug integration issues
- [ ] Verify basic end-to-end flow

### **Day 5: Verification & Stress Testing**
- [ ] Continuous streaming test (1000 blocks)
- [ ] Random backpressure test
- [ ] Burst mode test
- [ ] Lane saturation test
- [ ] Verify zero block loss
- [ ] Verify correct ordering
- [ ] Verify counter accuracy

### **Day 6: Synthesis & Metrics**
- [ ] Run synthesis
- [ ] Collect area report
- [ ] Collect timing report
- [ ] Calculate throughput
- [ ] Document results

### **Day 7: Presentation Prep**
- [ ] Prepare architecture slides
- [ ] Create demo waveforms
- [ ] Calculate performance metrics
- [ ] Rehearse presentation

## Build System (DEPS.yml)

### Individual Module Testing (Day 2-3)

```bash
# Person 1 - Test encryption lane
simulate tb_encryption_lane

# Person 2 - Test distributor
simulate tb_block_distributor

# Person 3 - Test combiner
simulate tb_output_combiner

# Person 4 - Test counter
simulate tb_performance_counter
```

### System Integration (Day 4-5)

```bash
# Quick test (100 blocks, fast debug)
simulate tb_crypto_accelerator_quick

# Full test (1000 blocks, complete verification)
simulate tb_crypto_accelerator_system
```

### Synthesis (Day 6)

```bash
# Synthesize complete system
synthesize dut_crypto_accelerator
```

## Interface Standard

All modules use **valid/ready handshake protocol:**

```systemverilog
// Transaction occurs when both valid and ready are HIGH
assign transaction = valid & ready;

// Source holds data stable when valid=1 and ready=0
// Sink controls flow via ready signal
```

**Rules:**
- Data is transferred only when `valid=1 AND ready=1` on the same clock edge
- When `valid=1` and `ready=0`, source must hold data stable
- No combinational path from `ready` input to `valid` output

## Module Interfaces Quick Reference

### crypto_accelerator_top
```systemverilog
input:  clk, rst_n, data_in[31:0], data_in_valid, data_out_ready
output: data_out[31:0], data_out_valid, data_in_ready, 
        blocks_processed[31:0], cycles_elapsed[31:0]
```

### block_distributor
```systemverilog
input:  clk, rst_n, data_in[31:0], data_in_valid, lane_ready[3:0]
output: lane_data[3:0][31:0], lane_seq_id[3:0][7:0], lane_valid[3:0], 
        data_in_ready
```

### encryption_lane
```systemverilog
input:  clk, rst_n, data_in[31:0], seq_id_in[7:0], data_in_valid, 
        data_out_ready
output: data_out[31:0], seq_id_out[7:0], data_out_valid, data_in_ready
```

### output_combiner
```systemverilog
input:  clk, rst_n, lane_data[3:0][31:0], lane_seq_id[3:0][7:0], 
        lane_valid[3:0], data_out_ready
output: data_out[31:0], data_out_valid, lane_ready[3:0]
```

### performance_counter
```systemverilog
input:  clk, rst_n, block_completed
output: blocks_processed[31:0], cycles_elapsed[31:0]
```

## Common Pitfalls to Avoid

### Distributor (Person 2)
- ❌ Accepting input when selected lane not ready → **blocks dropped**
- ✅ Gate `data_in_ready` with `lane_ready[lane_sel]`

### Encryption Lane (Person 1)
- ❌ Variable latency across different inputs → **combiner cannot reorder**
- ✅ Enforce fixed pipeline depth = 8 stages

### Combiner (Person 3)
- ❌ Outputting blocks in arrival order → **wrong sequence**
- ✅ Buffer and reorder based on sequence IDs

### Top-Level (Person 4)
- ❌ Forgetting to connect ready signals → **deadlock**
- ✅ Connect all valid/ready pairs bidirectionally

## Performance Metrics

### Theoretical Throughput
```
Throughput = (NUM_LANES × Clock_Frequency) / ENCRYPT_LATENCY
           = (4 × 500 MHz) / 8
           = 250 Mblocks/sec
```

### Speedup vs Single Lane
```
Speedup = NUM_LANES = 4×
```

### Utilization
```
Utilization = (blocks_processed × ENCRYPT_LATENCY) / (NUM_LANES × cycles_elapsed)
```

## Debug Tips

### Simulation
1. **Enable waveform dumping** - Essential for debugging
2. **Add assertions** - Check protocol violations
3. **Monitor sequence IDs** - Track block ordering
4. **Watch ready signals** - Verify backpressure

### Integration Issues
- Check signal width mismatches
- Verify array indexing (lane 0-3, not 1-4)
- Confirm handshake protocol on all interfaces
- Look for unconnected signals

## Success Criteria

### Module Level (Day 3)
- [ ] Each module passes standalone testbench
- [ ] Fixed latency verified (encryption lane)
- [ ] Round-robin verified (distributor)
- [ ] Ordering verified (combiner)

### System Level (Day 5)
- [ ] Zero block loss in 1000-block test
- [ ] Correct output ordering (sequence IDs match)
- [ ] Counter accuracy (blocks_processed = input count)
- [ ] No protocol violations (assertions pass)
- [ ] Handles backpressure correctly

### Synthesis (Day 6)
- [ ] No timing violations at target frequency
- [ ] Area within reasonable bounds
- [ ] Throughput matches theoretical calculation

## Resources

- **Architecture Spec:** `docs/multi_lane_crypto_accelerator_architecture.md`
- **DEPS Configuration:** `DEPS.yml`
- **Simulation Outputs:** `sim/` directory

## Questions or Issues?

1. Check the architecture specification first
2. Review interface definitions in Section 4
3. Consult timing diagrams in Section 5
4. Ask team during daily standup

---

**Ready to start? Begin with Day 1 architecture lockdown meeting!**

Good luck! 🚀
