# Jane Street ASIC Emulator
Programmable I/O (PIO) Protocol Emulator SoC for the 2027 Jane Street ASIC Challenge.

# Micro-Architecture Specification (MAS): PIO Protocol Emulator SoC
**Project:** Jane Street ASIC Challenge 2027
**Team:** Hilay, Krishna, Rudra
**Target:** Hardcaml Implementation / IHP 130nm CMOS5L (8x4 Tile Constraint)

## 1. Top-Level System Architecture
This System-on-Chip (SoC) operates as a highly flexible Programmable I/O (PIO) coprocessor, inspired by the RP2040 PIO state machines. Rather than implementing fixed, hardcoded FSMs for UART, SPI, or I2C, this architecture utilizes a unified execution engine that reads custom instruction words from an internal RAM block. 

*(Insert your AI-generated Architecture Diagram here)*

By executing a tiny Instruction Set Architecture (ISA) with cycle-level accuracy, the SoC can bit-bang any standard or custom serial protocol entirely through post-fabrication firmware. All blocks operate on a single synchronous system clock domain to ensure physical silicon viability.

## 2. The PIO Instruction Set Architecture (ISA)
The core execution engine processes 16-bit instruction words to manipulate standard generic I/O pins (e.g., `PIN0`, `PIN1`, `PIN2`). Protocol timing (baud rate, SPI clock frequency) is achieved dynamically via precise `WAIT` cycle instructions rather than fixed hardware dividers.

**Proposed 16-bit Instruction Format:** `[15:12] Opcode | [11:8] Pin Select | [7:0] Data/Value`

| Opcode (Hex) | Mnemonic | Description |
| :--- | :--- | :--- |
| `0x1` | `SET_PIN` | Drives the selected pin to the state defined in the Data field (1 or 0). |
| `0x2` | `WAIT_PIN` | Stalls execution until the selected input pin matches the Data field (e.g., wait for Start bit). |
| `0x3` | `WAIT_CYC` | Stalls execution for the number of system clock cycles defined in the Data field. |
| `0x4` | `SHIFT_OUT`| Pops 1 bit from the TX FIFO and drives it to the selected pin. |
| `0x5` | `SHIFT_IN` | Samples the selected pin and shifts 1 bit into the RX FIFO. |
| `0x6` | `JMP` | Jumps execution to the instruction RAM address specified in the Data field. |

## 3. Silicon-Specific Architectural Upgrades
Unlike basic FPGA behavioral logic, this ASIC architecture implements strict physical design rules optimized for the OpenLane/Yosys synthesis flow:
*   **Clock Domain Crossing (CDC):** All external input pins are routed through 2-stage flip-flop synchronizers before entering the PIO execution engine to prevent metastability from asynchronous external devices.
*   **Synchronous Clocking:** Derived clocks are strictly prohibited. The execution engine operates exclusively on the main `sys_clk`.
*   **FWFT Data Buffering:** Data streaming between the AXI-Lite bus and the PIO pins is managed by First-Word Fall-Through (FWFT) synchronous FIFOs, ensuring zero-latency data availability for `SHIFT_OUT` instructions.

## 4. Dynamic Memory & Register Map
The protocol logic is defined entirely by software writing to the Instruction RAM via the AXI-Lite bus.

| Address Offset | Register Name | Access | Description |
| :--- | :--- | :--- | :--- |
| `0x00` | `PIO_CTRL` | R/W | Bit [0]: PIO Enable, Bit [1]: Soft Reset |
| `0x04` | `PIO_STATUS` | R | Bit [0]: TX FIFO Full, Bit [1]: RX FIFO Empty |
| `0x08` | `PIO_TX_FIFO` | W | Push data byte for transmission |
| `0x0C` | `PIO_RX_FIFO` | R | Pop received data byte |
| `0x20 - 0x5F` | `INSTR_MEM` | R/W | 16-word x 16-bit Instruction RAM for custom protocol firmware |

## 5. Initial Resource Estimation (Pre-Hardcaml)
Based on preliminary Verilog prototyping, the estimated logic footprint for the IHP 130nm CMOS5L 8x4 tile constraint is highly optimized:
*   **Instruction RAM (16x16):** ~256 D-Flip-Flops
*   **FWFT FIFOs (16x8):** ~256 D-Flip-Flops
*   **Execution Engine & CDC:** ~150 LUTs, ~50 FFs
*   **Total Estimated Area:** Safely bounded within the 8x4 Tiny Tapeout physical constraint, leaving significant headroom for routing density.
