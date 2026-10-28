# RV32I Multicycle RISC-V Processor: Design, Verification and FPGA Implementation

Course project for **IL2234 – Digital Systems Design and Verification using Hardware Description Languages** (KTH).

A complete 32-bit RISC-V (RV32I subset) processor written in synthesizable **SystemVerilog**. It starts from a parametrizable ALU and grows into a multicycle CPU with a register file, a handshake-based memory subsystem and an FPGA top level for the **Digilent Urbana** board. Every block comes with a self-checking testbench, and most blocks also carry embedded SystemVerilog Assertions (SVA).

---

## Table of Contents

1. [Features](#features)
2. [Repository Structure](#repository-structure)
3. [Architecture](#architecture)
4. [Module Reference](#module-reference)
5. [Memory System and Bus Protocol](#memory-system-and-bus-protocol)
6. [Supported Instructions](#supported-instructions)
7. [Verification](#verification)
8. [FPGA Implementation (Urbana Board)](#fpga-implementation-urbana-board)
9. [Building and Simulating](#building-and-simulating)
10. [Design Notes and Known Limitations](#design-notes-and-known-limitations)
11. [Authors](#authors)

---

## Features

- Parametrizable **ALU** (`BW`, default 32) with 11 operations and `overflow / negative / zero` flags
- **Register file** with 32 registers, hard-wired `x0 = 0`, dual combinational read ports, synchronous write and asynchronous active-low reset
- **Multicycle CPU** driven by a 3-state FSM (`fetch`, `exec1`, `exec2`)
- RV32I subset: R-type, I-type ALU, loads/stores (byte/half/word), branches, `LUI`, `AUIPC`, `JAL`, `JALR`
- Byte-addressable memory interface with **byte write-enables**, sign/zero extension on loads and data alignment on stores
- Handshake memory protocol (`read_en` / `write_en` → `mem_ready`) with a small memory controller around a 64 KiB block RAM
- **Self-checking testbenches** for every level: ALU, RF, memory, CPU and full system
- **Constrained-random** instruction generation, reference models, random asynchronous resets and functional coverage
- **SVA assertions** guarded by `` `ifndef SYNTHESIS `` so they never reach the FPGA
- **FPGA top level** for the Urbana board: selectable CPU clock speed, PC and last-written data on the 7-segment displays, bus-status LEDs

---

## Repository Structure

Paths inside the SystemVerilog `include` directives (`../pkg/common_pkg.sv`, `../rtl/pkg/common_pkg.sv`) assume a layout like the one below. Adjust it if your folders differ.

```
.
├── rtl/
│   ├── pkg/
│   │   └── common_pkg.sv        # alu_pkg + ctrl_pkg (types, opcodes, FSM states)
│   ├── ALU.sv                   # Arithmetic Logic Unit
│   ├── RF.sv                    # Register file
│   ├── Register.sv              # Generic register with load enable (PC, IR)
│   ├── Mux.sv                   # One-hot AND-OR muxes (2x1, 3x1, 4x1)
│   ├── Decoder.sv               # Register address / immediate extraction
│   ├── Extension.sv             # Load data selection + sign/zero extension
│   ├── Data_Aligner.sv          # Store data replication (SB / SH / SW)
│   ├── Store_Encoder.sv         # Byte write-enable generation
│   ├── Controller.sv            # FSM + control signal generation + assertions
│   ├── Datapath.sv              # Datapath wiring
│   ├── CPU.sv                   # Controller + Datapath
│   ├── memory_controller.sv     # Memory handshake FSM
│   ├── Memory_System.sv         # memory_controller + data_sram (block RAM IP)
│   ├── CPU_system.sv            # CPU + memory system + bus assertions
│   └── urbana_top.sv            # FPGA top level (Urbana board)
├── tb/
│   ├── ALU_tb.sv
│   ├── RF_tb.sv
│   ├── Memory_tb.sv
│   ├── CPU_tb.sv                # Constrained-random instruction-level testbench
│   ├── CPU_cov.sv               # Functional coverage module
│   └── CPU_system_tb.sv         # Runs a real program on the full system
└── docs/
    ├── Milestone_1.pdf … Milestone_4.pdf
    └── Urbana_V2I1_SCH_2023-01-03.PDF   # Board schematic
```

> The memory subsystem instantiates `data_sram`, a **Xilinx Block Memory Generator IP** (16384 × 32 bit, byte-write enable). The IP configuration and the program initialization file are not part of the SystemVerilog sources and must be generated in Vivado.

---

## Architecture

See Documents section

### Execution model

The CPU is a **multicycle** machine with a Moore-style controller of three states:

| State   | Description |
|---------|-------------|
| `fetch` | Drives the PC onto the address bus and asserts `read_en`. Waits for `mem_ready`, then latches the instruction into IR. |
| `exec1` | Decodes the instruction. ALU, `LUI`, `AUIPC`, branches and jumps complete here and update the PC. For loads and stores the ALU computes `rs1 + imm` (the effective address). |
| `exec2` | Only for loads and stores. Drives the effective address, performs the memory access, waits for `mem_ready`, writes back loaded data (loads) and updates the PC. |

Because the memory answers a write after 1 cycle and a read after 2 cycles of latency, a typical instruction takes roughly: ALU/branch/jump ≈ 4 clock cycles, store ≈ 6, load ≈ 7 (derived from the RTL and memory controller, assuming no stalls other than the memory latency).

### Datapath muxes

All multiplexers use **one-hot select signals** generated by the controller (`MUX2x1`, `MUX3x1`):

- **ALU operand A**: `rs1` or `PC`
- **ALU operand B**: `rs2` or `imm`
- **Memory address**: `PC` (fetch) or ALU output (load/store)
- **Register-file write data**: ALU output, extended memory data, or `PC + 4` (`JAL`/`JALR`)
- **Next PC**: `PC + 4`, `PC + imm` (taken branch or `JAL`), or `ALU & ~3` (`JALR`)

Branches are evaluated with the ALU: `BEQ/BNE` use `XOR`, `BLT/BGE` use `SLT`, `BLTU/BGEU` use `SLTU`, and the controller selects the zero flag (or its complement) to decide whether the branch is taken.

---

## Module Reference

### `common_pkg.sv`
Defines two packages inside an include guard:
- `alu_pkg`: `alu_flags_t` (packed `{overflow, negative, zero}`) and `alu_op_t` (4-bit opcodes)
- `ctrl_pkg`: `state_t` (`fetch`, `exec1`, `exec2`) and `instr_type_t` (RV32I opcodes)

### `ALU`
Purely combinational, parametrizable by `BW`.

| Opcode | Name   | Result |
|--------|--------|--------|
| `0000` | ADD    | `in_a + in_b` |
| `0001` | SUB    | `in_a - in_b` |
| `0010` | SLL    | `in_a << shamt` |
| `0100` | SLT    | signed `in_a < in_b` → 1/0 |
| `0110` | SLTU   | unsigned `in_a < in_b` → 1/0 |
| `1000` | XOR    | `in_a ^ in_b` |
| `1010` | SRL    | logical `in_a >> shamt` |
| `1011` | SRA    | arithmetic `in_a >>> shamt` |
| `1100` | OR     | `in_a \| in_b` |
| `1110` | AND    | `in_a & in_b` |
| `1111` | PASS_B | `in_b` |

`shamt = in_b[$clog2(BW)-1:0]`. Unlisted opcodes output `0`.

Flags: `overflow` (signed overflow on ADD/SUB only), `negative` (MSB of result), `zero` (result is all zeros).

### `RF`
Parametrizable register file (`BW`, `DEPTH`; default 32 × 32).
- Two combinational read ports; reading address 0 or `chip_en = 0` returns 0
- One synchronous write port, active-low `write_en_n`, ignored for address 0 or when `chip_en = 0`
- Asynchronous active-low reset clears all registers (reset has priority over writes)
- Assertions: `x0` never changes, read ports return 0 for `x0`

### `Decoder`
Extracts `RS1`, `RS2`, `RD` and the sign-extended immediate for R, I, S, SB, U and UJ formats, selected by the controller's `Type_*` flags.

### `Extension`
Takes the 32-bit word from memory, selects the correct byte/halfword according to `addr[1:0]` and extends it: `LB`, `LH` (sign), `LBU`, `LHU` (zero), `LW` (pass-through).

### `Data_Aligner` and `Store_Encoder`
For stores, `Data_Aligner` replicates the byte or halfword across the word (`{4{b}}`, `{2{h}}`), while `Store_Encoder` generates the 4-bit byte write-enable from `addr[1:0]` and the store width.

### `Register`
Generic register with asynchronous active-low reset and a load enable. Used for the **PC** and the **instruction register (IR)**.

### `Controller`
Three-state FSM plus combinational decoding of control signals. Contains extensive assertions:
- one-hot / mutual-exclusion checks on all select signals
- per-instruction checks of the control-bus configuration in `exec1`/`exec2`
- temporal properties for FSM transitions, stalls on `mem_ready`, `loadIR`/`loadPC` timing and `read_en` behaviour
- warning on illegal opcodes

### `Datapath` and `CPU`
`Datapath` instantiates ALU, RF, Decoder, Extension, Data_Aligner, Store_Encoder, PC/IR registers and all muxes, and checks that the PC is never `X/Z` and always 4-byte aligned. `CPU` connects `Controller` and `Datapath`.

### `memory_controller`, `memory_system`, `CPU_system`
See the next section.

---

## Memory System and Bus Protocol

`memory_system` combines a small FSM (`memory_controller`) with the `data_sram` block RAM (14-bit word address, `addr[15:2]`, i.e. **64 KiB**). The address is aliased above 64 KiB.

`memory_controller` states: `WAIT → WRITE → WAIT` for writes, `WAIT → READ_1 → READ_2 → WAIT` for reads. `mem_ready` is high in `WRITE` and `READ_2`.

| Operation | Latency until `mem_ready` | Notes |
|-----------|---------------------------|-------|
| Write     | 1 cycle                   | `write_en` (4 bits, one per byte) |
| Read      | 2 cycles                  | `read_en` must be held until `mem_ready` |
| Idle      | n/a                       | `mem_ready` never rises without a request |

Protocol rules (checked by assertions in `memory_controller` and `CPU_system`):

- `mem_ready` is a **single-cycle pulse**
- Read and write requests must never be active together (write has priority, read would be lost)
- The request (`addr`, `read_en`, `write_en`, `wdata`) must stay stable until `mem_ready`
- A response must arrive within 2 cycles
- The address must not contain `X/Z`; read data must be known when returned
- Misaligned halfword/word accesses raise a warning

---

## Supported Instructions

| Class | Instructions |
|-------|--------------|
| R-type | `ADD SUB SLL SLT SLTU XOR SRL SRA OR AND` |
| I-type ALU | `ADDI SLTI SLTIU XORI ORI ANDI SLLI SRLI SRAI` |
| Loads | `LB LH LW LBU LHU` |
| Stores | `SB SH SW` |
| Branches | `BEQ BNE BLT BGE BLTU BGEU` |
| Upper immediate | `LUI AUIPC` |
| Jumps | `JAL JALR` |

Not implemented: `FENCE`, `ECALL`/`EBREAK`, CSR instructions, interrupts/exceptions. Illegal opcodes are ignored by the controller (they behave like a NOP that advances the PC) and trigger a warning in simulation.

---

## Verification

Every testbench is self-checking and prints a final PASS/FAIL summary.

| Testbench | DUT | Strategy |
|-----------|-----|----------|
| `ALU_tb` | `ALU` | Reference-model comparison. **Corner cross**: 12 corner operands × 12 corner operands × every opcode, then **2500 random** operations with corner-biased operand generation (zero, all ones, INT_MIN/MAX, one-hot, one-cold, small values). Checks both the result and all three flags. |
| `RF_tb` | `RF` (8 × 8-bit) | Shadow-memory model. Directed tests (reset priority over write, standby, write to `x0`, simultaneous read/write, write blocked in standby), followed by 1000 randomized cycles including random resets and standby periods. |
| `Memory_tb` | `memory_system` | Reference associative array with byte-lane updates, 5000 random reads/writes on a small address window, checks of `mem_ready` timing (1 cycle write / 2 cycles read) and **random asynchronous resets** hitting every controller state (hit counts are reported). |
| `CPU_tb` | `CPU` | Instruction-level, constrained-random. A `riscv_instr_item` class randomizes and packs legal instructions; the testbench emulates the memory handshake, back-door-initializes the register file, runs one instruction at a time and compares register/memory/PC against a software model. Nine phases: R-type, I-type, U-type, loads, stores, branches, JAL, JALR and a mixed random phase, plus **random asynchronous resets** with checks that PC, IR, FSM and RF return to their reset state. |
| `CPU_system_tb` | `CPU_system` | Runs a real program from the block RAM. It watches the final write to `0xA000` and checks the value `0x136F` (`25 + Σ(0…99) = 4975`), with a timeout. Also reports the number of cycles used. |

### Functional coverage (`CPU_cov`)
- `cg_instr`: every implemented instruction executed at least once
- `cg_mem`: load/store variants (kind × func3)
- `cg_br`: every branch condition both **taken and not taken**

Coverage is sampled once per executed instruction (in `exec1`) and printed at the end of the simulation. To use it, enable the `CPU_cov` instance that is currently commented out in `CPU_tb`.

### Assertions
Assertions are embedded in `ALU`, `RF`, `Controller`, `Datapath`, `memory_controller` and `CPU_system`. They are wrapped in `` `ifndef SYNTHESIS `` and are therefore ignored by synthesis. After a run, check the transcript for any `[...]` error messages even when the testbench reports a pass.

---

## FPGA Implementation (Urbana Board)

`urbana_top.sv` wraps `CPU_system` for the Digilent Urbana board (100 MHz clock).

### Clocking and reset
- `CLK_100MHZ` is divided down to a slow CPU clock that is routed through a `BUFG`
- `SW[15]` selects the speed: **100 Hz** (`SW[15] = 0`, `HALF_FAST = 500_000`) or **10 Hz** (`SW[15] = 1`, `HALF_SLOW = 5_000_000`). The switch is synchronized with a 2-flop synchronizer.
- `SW[0]` is the reset: low → CPU in reset, high → CPU runs. Reset assertion is asynchronous and the release is synchronized to the CPU clock.

### LEDs
| LED | Signal |
|-----|--------|
| `LED[0]` | `rst_n` |
| `LED[1]` | CPU clock |
| `LED[2]` | `bus_read_en` |
| `LED[3]` | `mem_ready` |
| `LED[7:4]` | `bus_write_en` |
| `LED[15:8]` | unused (0) |

### 7-segment displays
- **D1**: program counter (`bus_pc`, lower 16 bits)
- **D0**: last data word written to memory (`last_wdata`, lower 16 bits)

The displays are time-multiplexed (≈ 381 Hz per digit) using the free-running 100 MHz counter.

The slow clock makes it possible to watch the program run on the board. For the demo program, the PC changes while the data display ends on `136F`.

---

## Building and Simulating

The sources use SystemVerilog features such as `randcase`, constrained-random classes, covergroups, `unique0` and concurrent assertions. Use a simulator that supports them (for example QuestaSim, Xcelium or a recent Vivado xsim).

1. Compile `common_pkg.sv` first. All other files include it through the `include` path.
2. Compile the RTL for the level you want to test, together with the matching testbench.
3. Run the simulation and read the transcript.

Example (QuestaSim-style, adjust to your tool):

```bash
# ALU
vlog rtl/pkg/common_pkg.sv rtl/ALU.sv tb/ALU_tb.sv
vsim -c ALU_tb -do "run -all; quit"

# Register file
vlog rtl/RF.sv tb/RF_tb.sv
vsim -c RF_tb -do "run -all; quit"

# Full CPU (instruction-level random verification, with coverage module)
vlog rtl/pkg/common_pkg.sv rtl/*.sv tb/CPU_cov.sv tb/CPU_tb.sv
vsim -c CPU_tb -do "run -all; quit"
```

`Memory_tb` and `CPU_system_tb` need the `data_sram` IP: generate it in Vivado (Block Memory Generator, 16384 × 32 bit, byte write enable, initialized with the test program) and add its simulation model to the compile list.

For the FPGA build, create a Vivado project for the Urbana board, add `rtl/` plus the `data_sram` IP and a constraints file mapping `CLK_100MHZ`, `SW`, `LED`, `D0_SEG/AN` and `D1_SEG/AN` (see the board schematic in `docs/`), set `urbana_top` as top module, and generate the bitstream.

---

## Design Notes and Known Limitations

- **Multicycle, not pipelined**: one instruction in flight, no forwarding or hazards to handle.
- **No exceptions**: misaligned accesses only trigger a simulation warning; illegal opcodes only trigger a warning.
- **JALR** clears the two lowest bits of the target (`& ~3`) to keep the PC word-aligned, which is stricter than the RISC-V rule of clearing only bit 0.
- **Memory size** is fixed at 64 KiB by the block RAM address width (`addr[15:2]`).
- **No memory-mapped peripherals**: the display and LEDs are driven by observing the memory bus, not by dedicated I/O registers.
- Testbenches use hierarchical references (`DUT.Datapath.RF1.mem`, `DUT.Controller.pstate`, …), so instance names in `CPU`/`Datapath` must not be changed without updating them.
- `CPU_system` exposes the extra output `bus_mem_ready`, used by the FPGA top level. Make sure the testbench instance (`CPU_system_tb`) matches the port list of your version of the module.

---

## Authors

 Project for IL2234, KTH Royal Institute of Technology.

- Matteo Zorat

