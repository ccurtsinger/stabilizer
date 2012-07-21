#!/usr/bin/env python

import os
import sys

benchmarks = ['astar', 'bwaves', 'bzip2', 'calculix', 'gcc', 'gobmk', 'gromacs', 'h264ref', 'hmmer', 'lbm', 'leslie3d', 'libquantum', 'mcf', 'milc', 'namd', 'perlbench', 'sjeng', 'sphinx3', 'wrf', 'zeusmp']
train_benchmarks = ['calculix', 'gcc', 'libquantum', 'mcf', 'mic', 'namd', 'sphinx3']

iterations = 10
to_run = []
dont_run = []

for arg in sys.argv[1:]:
	if arg in benchmarks:
		to_run.append(arg)
	elif arg.startswith('-') and arg[1:] in benchmarks:
		dont_run.append(arg[1:])
	else:
		iterations = int(arg)

if len(to_run) == 0:
	to_run = benchmarks

for bmk in dont_run:
	if bmk in to_run:
		to_run.remove(bmk)

def runspec(bench, size, ext, n, rebuild=False):
	cmd = 'runspec --config=szc --mach=linux --action=run --tune=base --size='+size+' --ext='+ext+' -n '+str(n)
	if rebuild:
		cmd += ' --rebuild'
	cmd += ' '+bench

	os.system(cmd)

for bmk in to_run:
	if bmk in train_benchmarks:
		size = 'train'
	else:
		size = 'test'

	runspec(bmk, size, 'code', iterations)
	runspec(bmk, size, 'code.stack', iterations)
	runspec(bmk, size, 'code.heap.stack', iterations)
	for i in range(0, iterations):
		runspec(bmk, size, 'link', 1, rebuild=True)

