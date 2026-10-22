# jane-street-asic-emulator
Programmable UART, SPI, and I2C protocol emulator SoC for the 2027 Jane Street ASIC Challenge.
# Micro-Architecture Specification (MAS): Protocol Emulator SoC
**Project:** Jane Street ASIC Challenge 2027

**Team:** Hilay, Krishna, Rudra

**Target:** Hardcaml Implementation / IHP 130nm CMOS5L 

## 1. Top-Level System Architecture
This System-on-Chip (SoC) emulates standard hardware communication protocols. To ensure physical silicon viability, all IP blocks operate on a single synchronous system clock domain. 

*(Insert your AI-generated Architecture Diagram here by typing `/diagram` and selecting it)*

## 2. Silicon-Specific Architectural Upgrades
Unlike basic FPGA behavioral logic, this ASIC architecture implements strict physical design rules:
*   **Clock Domain Crossing (CDC):** External asynchronous inputs (`UART_RX` and `SPI_MISO`) are routed through 2-stage flip-flop synchronizers before entering the control logic to prevent metastability.
*   **Synchronous Clocking:** Derived clocks (e.g., `sclk <= ~sclk`) are strictly prohibited to avoid clock skew and synthesis violations. All protocol timing is handled via synchronous `clock_enable` pulses generated from the main `sys_clk`.
*   **Oversampling:** The UART receiver utilizes a 16x baud rate oversampling scheme with majority voting to filter out physical wire noise.

## 3. Dynamic Memory & Register Map
Parameters are not hardcoded. The emulators are parameterized dynamically via the AXI-Lite bus.

| Address Offset | Register Name | Access | Description |
| :--- | :--- | :--- | :--- |
| `0x00` | `UART_CTRL` | R/W | Bit [0]: Enable, Bits [15:1]: Baud Rate Divisor |
| `0x04` | `UART_TX_DATA` | W | UART Transmit FIFO data entry |
| `0x08` | `UART_RX_DATA` | R | UART Receive FIFO data read |
| `0x10` | `SPI_CTRL` | R/W | Bit [0]: Enable, Bit [1]: CPOL, Bit [2]: CPHA, Bits [15:3]: Clock Divider |
| `0x14` | `SPI_DATA` | R/W | SPI Transmit/Receive Shift Register |
| `0x20` | `I2C_CTRL` | R/W | Bit [0]: Master Enable, Bits [7:1]: Target Address |
| `0x24` | `I2C_DATA` | R/W | I2C Transmit/Receive Register |
| `0x28` | `I2C_STATUS` | R | Bit [0]: Bus Busy, Bit [1]: ACK Error |

## 4. I2C Finite State Machine (FSM)
The I2C FSM rigorously controls the open-drain bidirectional lines (`SDA`, `SCL`) via tri-state buffers.
**Master Transmission Flow:**
1. **IDLE:** Wait for Start command from AXI-Lite Bus.
2. **START:** Pull `SDA` low while `SCL` is high.
3. **ADDR_TX:** Shift out 7-bit target address.
4. **RW_BIT:** Send Write (0) or Read (1) bit.
5. **ACK_WAIT:** Release `SDA`, sample on next `SCL` high for target ACK.
6. **DATA_TX / RX:** Shift 8 bits of payload data.
7. **STOP:** Release `SDA` while `SCL` is high.
## 5. Initial Resource Estimation (Pre-Hardcaml)
Based on preliminary Verilog prototypes synthesized in Xilinx Vivado, the estimated logic footprint for the silicon tile constraints is as follows:

- **UART Block:** ~150 LUTs, ~100 FFs
- **SPI Block:** ~120 LUTs, ~80 FFs
- **I2C Block:** ~250 LUTs, ~150 FFs
- **Total Estimated Area:** Well within the provided challenge tile constraint.


