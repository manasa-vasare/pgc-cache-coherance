#!/usr/bin/env bash
# run_experiments.sh - Automated runner for Cache Coherence & NUMA Evaluation

set -e

echo "=========================================================="
echo " Experiment: Cache Coherence (MSI/MESI/MOESI) & NUMA"
echo "=========================================================="

echo -e "\n[1/5] Checking Hardware & NUMA Topology..."
lscpu | grep -E "Socket|Core|Thread|NUMA" || true
numactl --hardware || true

echo -e "\n[2/5] Running Protocol Simulator (src/coherence_sim.py)..."
python3 src/coherence_sim.py 1000

echo -e "\n[3/5] Compiling C Benchmarks from src/..."
make clean
make all

echo -e "\n[4/5] Running Program 2: False Sharing Test (3 iterations each)..."
echo "--- Adjacent Layout (2 Threads) ---"
for i in 1 2 3; do
    OMP_NUM_THREADS=2 ./false_sharing adjacent
done

echo "--- Padded Layout (2 Threads) ---"
for i in 1 2 3; do
    OMP_NUM_THREADS=2 ./false_sharing padded
done

echo -e "\n[5/5] Running Program 3 & 4: NUMA Sweep & Scalability Comparison..."
./compare_numa

echo "--- Local vs Remote NUMA Sweep (1 Thread) ---"
for i in 1 2 3; do
    OMP_NUM_THREADS=1 numactl --cpunodebind=0 --membind=0 ./numa_sweep 512
done
for i in 1 2 3; do
    OMP_NUM_THREADS=1 numactl --cpunodebind=0 --membind=1 ./numa_sweep 512
done

echo "--- Local vs Remote NUMA Sweep (2 Threads) ---"
for i in 1 2 3; do
    OMP_NUM_THREADS=2 numactl --cpunodebind=0 --membind=0 ./numa_sweep 512
done
for i in 1 2 3; do
    OMP_NUM_THREADS=2 numactl --cpunodebind=0 --membind=1 ./numa_sweep 512
done

echo -e "\nAll benchmarks completed successfully!"
