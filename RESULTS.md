# Experimental Results & Performance Analysis

This document provides the raw data, computed statistics, speedup metrics, and hardware-level analysis for the Cache Coherence (MSI, MESI, MOESI) and NUMA memory placement benchmarks.

---

## 1. Experimental Environment & Hardware Setup

| Parameter | Specification |
| :--- | :--- |
| **Host Processor** | 13th Gen Intel® Core™ i5-13400 (Desktop CPU, Single Physical Socket, UMA) |
| **Virtualization** | VMware Workstation Pro on Ubuntu 22.04 LTS |
| **Virtual Sockets** | 2 virtual sockets (configured via `.vmx` advanced parameters) |
| **Cores & Threads** | 2 cores per socket, 1 thread per core (4 vCPUs total: vCPU 0, 1, 2, 3) |
| **NUMA Topology** | Node 0: CPUs `0, 1` (2014 MB); Node 1: CPUs `2, 3` (1389 MB) |
| **Node Distances** | Local (Node 0 $\leftrightarrow$ Node 0): 10; Remote (Node 0 $\leftrightarrow$ Node 1): 20 |
| **Compiler & Tools** | GCC 15.2.0 (`-O2 -fopenmp`), OpenMP (libgomp), `numactl`, Python 3.14 |

---

## 2. Part A: Protocol Simulation Results (`coherence_sim.py`)

Workload: 1,000 iterations of alternating Core 0 and Core 1 reads and writes ($1,000 \times 4 = 4,000$ memory operations).

### 2.1 State Trace: First 2 Iterations (Adjacent Layout)

```
Operation             MSI (C0 / C1)     MESI (C0 / C1)    MOESI (C0 / C1)
-------------------------------------------------------------------------
core 0 reads counter      S / I             E / I             E / I
core 0 writes counter     M / I             M / I             M / I
core 1 reads counter      S / S             S / S             O / S
core 1 writes counter     I / M             I / M             I / M
core 0 reads counter      S / S             S / S             S / O
core 0 writes counter     M / I             M / I             M / I
core 1 reads counter      S / S             S / S             O / S
core 1 writes counter     I / M             I / M             I / M
```

### 2.2 Aggregate Statistics (4,000 Memory Operations)

| Layout | Protocol | Bus Transactions | BusRd | BusRdX | BusUpgr | Invalidations | Writebacks (WB) | Cache-to-Cache (C2C) | Silent E $\rightarrow$ M |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **adjacent** | **MSI** | **4,000** | 2,000 | 0 | 2,000 | 1,999 | **1,999** | 0 | 0 |
| **adjacent** | **MESI** | **3,999** | 2,000 | 0 | 1,999 | 1,999 | **1,999** | 0 | 1 |
| **adjacent** | **MOESI** | **3,999** | 2,000 | 0 | 1,999 | 1,999 | **0** | **3,998** | 1 |
| **padded** | **MSI** | **4** | 2 | 0 | 2 | 0 | 0 | 0 | 0 |
| **padded** | **MESI** | **2** | 2 | 0 | 0 | 0 | 0 | 0 | **2** |
| **padded** | **MOESI** | **2** | 2 | 0 | 0 | 0 | 0 | 0 | **2** |

### 2.3 Protocol Findings:
1. **MSI Bus Overhead:** In the adjacent layout, every write to a shared line requires a `BusUpgr`, and every read by the other core forces a high-latency writeback to main memory (1,999 writebacks).
2. **MESI Private Optimization:** MESI eliminates the initial bus upgrade transaction when private data is first written via silent transition from Exclusive to Modified (`Silent E->M = 1`).
3. **MOESI Memory Traffic Elimination:** MOESI eliminates all 1,999 writebacks to RAM by introducing the **Owned (O)** state. The owning cache directly serves the requested data to the reading cache via 3,998 Cache-to-Cache (C2C) transfers.
4. **Padding Benefit:** Placing variables on independent lines eliminates invalidations entirely ($1,999 \rightarrow 0$) and reduces total bus transactions from ~4,000 down to **2**.

---

## 3. Part B: False Sharing & Parallel Scalability Results

Workload: $100,000,000$ increments in total divided among threads.

### 3.1 Two-Thread False Sharing Measurements (`false_sharing.c`)

#### Single / Initial Run:
* Adjacent layout: `0.0175 s`
* Padded layout: `0.0121 s`
* **Cost of False Sharing:** $\frac{0.0175}{0.0121} = \mathbf{1.446\times}$ (**44.6% performance degradation**)

#### 3 Repeated Runs (Filtering Noise / System Jitter):
| Run | Adjacent Time (s) | Padded Time (s) |
| :---: | :---: | :---: |
| 1 | 0.0182 | 0.0128 |
| 2 | 0.0148 | 0.0112 |
| 3 | 0.0134 | 0.0113 |
| **Median** | **0.0148 s** | **0.0113 s** |
| **Mean** | 0.0155 s | 0.0118 s |

$$\text{False Sharing Penalty (Median)} = \frac{0.0148\text{ s}}{0.0113\text{ s}} = \mathbf{1.310\times} \quad (+31.0\% \text{ execution time})$$

---

### 3.2 Thread Scalability Benchmark (`compare_numa` Table 1)

| Layout | Threads | Total Increments | Status | Execution Time (s) | Speedup vs 1T | Scaling Efficiency | False Sharing Penalty ($\frac{T_{\text{adj}}}{T_{\text{pad}}}$) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Adjacent** | 1 | 100,000,000 | Correct | 0.0236 | $1.00\times$ | 100% | \multirow{2}{*}{$1.054\times$ (Negligible)} |
| **Padded** | 1 | 100,000,000 | Correct | 0.0224 | $1.00\times$ | 100% | |
| **Adjacent** | 2 | 100,000,000 | Correct | 0.0148 | $1.595\times$ | 79.8% | \multirow{2}{*}{$\mathbf{1.321\times}$ (+32.1% time)} |
| **Padded** | 2 | 100,000,000 | Correct | 0.0112 | $\mathbf{2.000\times}$ | **100.0% (Linear)** | |
| **Adjacent** | 4 | 100,000,000 | Correct | 0.0095 | $2.484\times$ | 62.1% | \multirow{2}{*}{$\mathbf{1.267\times}$ (+26.7% time)} |
| **Padded** | 4 | 100,000,000 | Correct | 0.0075 | $\mathbf{2.987\times}$ | 74.7% | |

#### Key Scalability Insights:
* **Data Correctness:** In all test runs, the final increment sum is verified to be $100,000,000$. Hardware cache coherence ensures correctness at all thread counts.
* **Scaling Degradation:** At 2 threads, the padded version achieves exact theoretical linear scaling ($2.00\times$), whereas the adjacent version achieves only $1.60\times$ due to continuous cache line invalidations and bus arbitration.
* **At 4 threads:** Padded reaches $2.99\times$ speedup, demonstrating that eliminating false sharing allows applications to unlock true multi-core parallel efficiency.

---

## 4. Part C: NUMA Memory Placement Results (`numa_sweep.c`)

Workload: 512 MB memory buffer read in 4 sequential passes (stride = 64 bytes).

### 4.1 Single Standalone Runs
* 1 Thread Local (`--membind=0`): `0.1323 s`
* 1 Thread Remote (`--membind=1`): `0.1654 s` $\rightarrow$ $\frac{0.1654}{0.1323} = \mathbf{1.250\times}$
* 2 Threads Local (`--membind=0`): `0.1001 s`
* 2 Threads Remote (`--membind=1`): `0.3619 s` $\rightarrow$ $\frac{0.3619}{0.1001} = \mathbf{3.615\times}$ *(initial cold page allocation)*

### 4.2 3 Repeated Runs (Steady-State Benchmark)

| Configuration | Run 1 (s) | Run 2 (s) | Run 3 (s) | **Median (s)** | Min (s) |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **1 Thread - Local (`--membind=0`)** | 0.1322 | 0.1272 | 0.0999 | **0.1272** | 0.0999 |
| **1 Thread - Remote (`--membind=1`)** | 0.1450 | 0.1278 | 0.1082 | **0.1278** | 0.1082 |
| **2 Threads - Local (`--membind=0`)** | 0.1354 | 0.1175 | 0.0961 | **0.1175** | 0.0961 |
| **2 Threads - Remote (`--membind=1`)** | 0.1375 | 0.1204 | 0.0964 | **0.1204** | 0.0964 |

### 4.3 NUMA Ratio Analysis:
$$\text{NUMA Penalty (1 Thread)} = \frac{0.1278\text{ s}}{0.1272\text{ s}} = \mathbf{1.005\times} \quad (+0.5\%)$$
$$\text{NUMA Penalty (2 Threads)} = \frac{0.1204\text{ s}}{0.1175\text{ s}} = \mathbf{1.025\times} \quad (+2.5\%)$$

### 4.4 Hardware Explanation (Virtual vs. Physical Topology):
1. **Underlying Physical Architecture:** The host processor is an **Intel Core i5-13400**, a client-grade desktop processor with a single physical memory controller and unified dual-channel DDR memory bus (UMA).
2. **Virtual NUMA Nodes:** Although VMware successfully creates two virtual NUMA nodes in the Linux kernel via ACPI SLIT/SRAT tables, both virtual nodes access the **same physical RAM** through the exact same physical bus.
3. **Cold Allocation Overhead:** The large difference on the first cold sweep ($0.3619\text{ s}$ vs. $0.1001\text{ s}$) represents the hypervisor page allocation and initial shadow page table mapping overhead across virtual NUMA boundaries. In steady state, once memory pages are resident, local and remote access latencies are virtually identical ($\approx 1.0\times$).

---

## 5. Summary Observation Table

| Case | Correctness | Relative Performance | Scalability | Key Mechanism Observed |
| :--- | :---: | :--- | :--- | :--- |
| **MSI (Simulated)** | Correct | Slowest / High Bus Traffic | Poor on shared lines | 4,000 bus tx; 1,999 memory writebacks |
| **MESI (Simulated)** | Correct | Moderate Bus Traffic | Good for private lines | Saves upgrade on private write (Silent E $\rightarrow$ M) |
| **MOESI (Simulated)** | Correct | Lowest Memory Traffic | High | **0 writebacks** to RAM; 3,998 C2C transfers |
| **Adjacent Counters** | Correct | 27% – 45% Slower | Sub-linear ($1.6\times$ 2T, $2.48\times$ 4T) | Cache-line ping-pong across cores |
| **Padded Counters** | Correct | Fastest | **Linear** ($2.0\times$ 2T, $2.99\times$ 4T) | 64-byte alignment isolates thread writes |
| **Local Memory** | Correct | Baseline reference (~0.12 s) | Baseline | Optimal memory placement |
| **Remote Memory** | Correct | $\approx 1.0\times$ steady state (3.6x cold) | Scalable | Confirms single-socket physical UMA behavior |
