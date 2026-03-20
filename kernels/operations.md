### 📑 ISA SPECIFICATION: MPC-64 ULTRA COMPUTE ENGINE (v1.0)

Total Operations: 16 Core Instructions
Data Width: 1024-bit (Vectorized)
Deterministic Window: All ops must complete within T1-T22.

---

#### 1. TENSOR OPS (Matrix Multiplication)
Heavy-duty math blocks. Pipelined for maximum throughput.


| Mnemonic   | OpCode | Latency | Description |
| :---       | :---:  | :---:   | :--- |
| **TMAC_4x4** | 0x10   | 4 Ticks | **Matrix Multiply-Accumulate.** 4x4 matrix (16 elements) multiply and add to V_ACC. Primary AI workload. |
| **V_MUL**    | 0x11   | 4 Ticks | **Element-wise Multiplication.** [16x64-bit] or [64x16-bit] parallel multipliers. |
| **V_ADD**    | 0x12   | 1 Tick  | **Vector Addition.** Parallel 1024-bit adder tree. |
| **V_DIV**    | 0x13   | 12 Ticks| **Vector Division.** Iterative approximation (Newton-Raphson). Managed by multi-cycle path. |

---

#### 2. BITWISE LOGIC (1-Cycle Ops)
Ultra-fast operations for masking and logical branching.


| Mnemonic   | OpCode | Latency | Description |
| :---       | :---:  | :---:   | :--- |
| **V_AND**    | 0x20   | 1 Tick  | Bitwise AND across 1024 bits. Used for masking. |
| **V_OR**     | 0x21   | 1 Tick  | Bitwise OR. |
| **V_XOR**    | 0x22   | 1 Tick  | Bitwise XOR. |
| **V_NXOR**   | 0x23   | 1 Tick  | Bitwise NOT-XOR. Used for fast vector equality checks. |

---

#### 3. NON-LINEAR ACTIVATIONS (SRAM LUT-based)
Uses internal 256-entry Look-Up Table (1KB per core) for 0.5ns response.


| Mnemonic   | OpCode | Latency | Description |
| :---       | :---:  | :---:   | :--- |
| **V_RELU**   | 0x30   | 1 Tick  | **Rectified Linear Unit.** Hardware gate: if(bit_sign) val=0. |
| **V_SIGM**   | 0x31   | 1 Tick* | **Sigmoid.** LUT-based approximation (1/(1+e^-x)). |
| **V_TANH**   | 0x32   | 1 Tick* | **Hyperbolic Tangent.** LUT-based approximation. |
| **V_LUT_LD** | 0x3F   | 1 Tick  | **Load LUT.** Allows Senior Scheduler to update Activation Functions in real-time. |

---

#### 4. DATA MOVEMENT & FLOW
Managing L1 SRAM and internal state.


| Mnemonic   | OpCode | Latency | Description |
| :---       | :---:  | :---:   | :--- |
| **LD_WIDE**  | 0x40   | 1 Tick  | Load 1024-bit from L1 SRAM to V-Register. |
| **ST_WIDE**  | 0x41   | 1 Tick  | Store 1024-bit from V-Register to L1 SRAM. |
| **V_SHFT**   | 0x42   | 1 Tick  | Barrel shifter for 1024-bit vector (Normalization). |
| **DONE_SIG** | 0x0F   | 1 Tick  | Trigger completion signal to Segment Scheduler (Closes the 152-tick window). |

---

### 🛠️ IMPLEMENTATION NOTES:
1. **LUT Interpolation:** For V_SIGM/V_TANH, the core uses the 8 most significant bits (MSB) as an index. If high precision is required, the scheduler can trigger a 3-tick linear interpolation mode.
2. **Clock Gating:** Any ALU block not in use by the current OpCode is automatically gated (power-cut) to maintain 220W TDP.
3. **Multi-Cycle DIV:** V_DIV is the only instruction that breaks the 4-tick compute rule. It is handled by the Segment Scheduler as a "Long Task".
