// MPC-64 Firmware: Matrix Multiplication 4x4 (16 elements)
// Input: V1 (weights, 1024b), V2 (input data, 1024b)
// Output: Result stored in the first slot of V3

// Step 1: Element-wise multiplication of the entire 1024-bit pack (16 numbers in 1 clock)
VMUL V3, V1, V2, 0xFFFF

// Step 2: Reduction (Folding). Sum 16 results into 1 using the hardware Adder Tree (4 clocks)
VRED V3, V3, 0, 0xFFFF

// Step 3: Apply AI activation (ReLU) to the result
VRELU V3, V3, 0, 0x0001

// Step 4: Finish. Segment Planner detects the HALT flag and retrieves V3
HALT
