# Makefile for Cache Coherence & NUMA Performance Evaluation

CC = gcc
CFLAGS = -O2 -Wall -fopenmp
PYTHON = python3

SRCDIR = src

TARGETS = false_sharing numa_sweep compare_numa

all: $(TARGETS)

false_sharing: $(SRCDIR)/false_sharing.c
	$(CC) $(CFLAGS) -o $@ $<

numa_sweep: $(SRCDIR)/numa_sweep.c
	$(CC) $(CFLAGS) -o $@ $<

compare_numa: $(SRCDIR)/compare_numa.c
	$(CC) $(CFLAGS) -o $@ $<

sim:
	$(PYTHON) $(SRCDIR)/coherence_sim.py 1000

run: all
	@echo "=== Running False Sharing (2 threads) ==="
	OMP_NUM_THREADS=2 ./false_sharing adjacent
	OMP_NUM_THREADS=2 ./false_sharing padded
	@echo "=== Running Unified Benchmark ==="
	./compare_numa

clean:
	rm -f $(TARGETS) *.o
