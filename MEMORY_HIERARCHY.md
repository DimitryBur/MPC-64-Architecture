# 🧠 Memory Hierarchy: Deterministic Dataflow (MPC-64)

The **MPC-64 Ultra** memory hierarchy is engineered for extreme 1024-bit bandwidth and near-zero jitter. We utilize a **Near-Memory Computing** principle to eliminate traditional von Neumann bottlenecks.

### 1. Tiered Latency Model (Target: 2.0 GHz)


| Layer | Type | Capacity (per Segment) | Latency | Bandwidth |
| :--- | :--- | :--- | :--- | :--- |
| **L1 (Local)** | Private SRAM | 16 KB / core | **1 Cycle (0.5 ns)** | 1024-bit / cycle |
| **L2 (Segment)** | Shared SRAM | 4 MB / segment | **8-12 Cycles** | 2048-bit / cycle |
| **Global Spine** | Ring Bus | Unified Buffer | **1 Cycle / Hop** | 1024-bit / cycle |
| **External** | HBM3 / DDR5 | Managed by Host | **150+ Cycles** | Up to 819 GB/s |

### 2. L1: Zero-Wait Compute
Each MPC-64 core features **16 KB of private SRAM** divided into two functional banks:
*   **Weight Buffer (8 KB):** Stores active layer coefficients.
*   **Activation Buffer (8 KB):** Stores incoming data (activations).
*   **Mechanism:** Integrated 1024-bit wide vector registers allow for instantaneous data streaming from L1 directly into the **4x4 Tensor MAC** unit.

### 3. L2: Segmented Orchestration (Managed Buffer)
Unlike traditional "blind" caches, the MPC-64 L2 is a **software-defined buffer** managed by the Leaf Schedulers:
*   **Snapshot Logic:** L2 retains copies of current tasks. If a core triggers a hard timeout, the scheduler instantly re-dispatches the task from L2 without requesting data from the main bus.
*   **Double Buffering:** While cores process "Buffer A," the Global Spine pre-fetches "Buffer B" into the secondary L2 bank, ensuring 100% compute utilization.

### 4. 1024-bit Copper Spine (The Data Highway)
The interconnect is the backbone of the system's thermal and data integrity:
*   **Smart Broadcast:** Neural weights are broadcasted once across the entire ring, populating the L2 of every segment simultaneously. This reduces external memory pressure by 10x-100x compared to standard GPU architectures.
*   **Collision-Free Routing:** Thanks to deterministic 80% load balancing, bus collisions are mathematically eliminated during the **MPD Dialect** compilation phase.

### 5. Deterministic Access (Zero Jitter)
In contrast to NVIDIA GPUs, where memory latency can vary based on warp scheduling and cache misses, **MPC-64** access times are **fixed**. This allows AI compilers to perfectly schedule every operation, guaranteeing a stable **2.0 GHz throughput** with no stalls.

---
**Keywords:** Near-Memory Computing, SRAM Latency, 1024-bit Bus, Data Reuse, AI Hardware Scaling, Zero Jitter.
