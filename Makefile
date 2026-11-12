# Makefile for Cache Coherence & NUMA Performance Evaluation

CC = gcc
CFLAGS = -O2 -Wall -fopenmp
PYTHON = python3

TARGETS = false_sharing numa_sweep compare_numa

all: $(TARGETS)

false_sharing: false_sharing.c
	$(CC) $(CFLAGS) -o $@ $<

numa_sweep: numa_sweep.c
	$(CC) $(CFLAGS) -o $@ $<

compare_numa: compare_numa.c
	$(CC) $(CFLAGS) -o $@ $<

sim:
	$(PYTHON) coherence_sim.py 1000

run: all
	@echo "=== Running False Sharing (2 threads) ==="
	OMP_NUM_THREADS=2 ./false_sharing adjacent
	OMP_NUM_THREADS=2 ./false_sharing padded
	@echo "=== Running Unified Benchmark ==="
	./compare_numa

clean:
	rm -f $(TARGETS) *.o
