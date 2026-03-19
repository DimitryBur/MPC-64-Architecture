# MPC-64 Architecture
A Massive Parallel Computing architecture designed for AI and high-performance computing.

## Key Features
- **4096 Cores**: 64 segments with 64 cores each.
- **VPU (Vector Processing Unit)**: Every core operates with **1024-bit** registers.
- **Hierarchical Scheduling**: Global and Segment planners manage data flow without core-to-core communication overhead.
- **Dynamic Firmware**: Instruction sets are stored in SRAM and can be swapped "on-the-fly" by the host controller.

## Repository Structure
- `/verilog`: Hardware description of ALU, Core, and Planners.
- `/docs`: ISA and architectural specifications.
- `/kernels`: Sample assembly firmware for AI tasks.
