# MPC-64 Instruction Set Architecture (ISA)

The **MPC-64** project (Massive Parallel Computing) utilizes a hierarchical control flow: **Global Scheduler -> Segment Planner -> Core**. 
Cores are "flashless"; firmware (instruction blocks) is loaded into local **SRAM** (64 words x 64-bit) by the Global Scheduler before execution.

## Core Register Model
- **V0 - V15**: 16 vector registers, **1024-bit** each.
- Each V-register holds **16 elements of 64-bit** (Double Precision / Int64).
- **ACC**: Internal accumulator for reduction operations.

## Instruction Format (64-bit)


| Opcode (4b) | Dest Reg (4b) | Src1 (4b) | Src2 (4b) | V-Mask (16b) | Immediate/Offset (32b) |
|:-----------:|:-------------:|:---------:|:---------:|:------------:|:----------------------:|

## Instruction List (ALU)


| Opcode | Mnemonic | Description |
|:-------|:---------|:------------|
| `0001` | **VADD** | Element-wise addition: `V1 + V2 -> Dest` |
| `0010` | **VSUB** | Element-wise subtraction: `V1 - V2 -> Dest` |
| `0011` | **VMUL** | Element-wise multiplication: `V1 * V2 -> Dest` |
| `1000` | **VRELU**| Zero out elements in `V1` if `< 0` (AI Activation) |
| `1001` | **VMAC** | Multiply-Accumulate: `(V1 * V2) + Dest -> Dest` |
| `1010` | **VRED** | **Reduction Sum**: Sum all 16 elements of `V1` into a single 64-bit value using the **Adder Tree**. |
| `1111` | **HALT** | Stops the Core and signals `READY` to the Segment Planner. |
