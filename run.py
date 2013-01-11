#!/usr/bin/env python

import os
import sys

benchmarks = ['astar', 'bwaves', 'bzip2', 'calculix', 'gcc', 'gobmk', 'gromacs', 'h264ref', 'hmmer', 'lbm', 'leslie3d', 'libquantum', 'mcf', 'milc', 'namd', 'perlbench', 'sjeng', 'sphinx3', 'wrf', 'zeusmp']
train_benchmarks = ['calculix', 'gcc', 'lbm', 'libquantum', 'mcf', 'milc', 'namd', 'sphinx3', 'perlbench']

iterations = 10
to_run = []
dont_run = []
configs = ['code', 'code.stack', 'code.heap.stack', 'stack', 'heap.stack', 'heap', 'link']
tune = 'base'
size = 'default'
run_configs = []

for arg in sys.argv[1:]:
	if arg in benchmarks:
		to_run.append(arg)
	elif arg.startswith('-') and arg[1:] in benchmarks:
		dont_run.append(arg[1:])
	elif arg in configs:
		run_configs.append(arg)
	elif arg in ['base', 'peak']:
		tune = arg
	elif arg in ['default', 'test', 'train', 'ref']:
		size = arg
	else:
		iterations = int(arg)

if len(to_run) == 0:
	to_run = benchmarks

if len(run_configs) == 0:
	run_configs = configs

for bmk in dont_run:
	if bmk in to_run:
		to_run.remove(bmk)

def runspec(bench, size, tune, ext, n, rebuild=True):
	cmd = 'runspec --config=szc --mach=linux --action=run --tune='+tune+' --size='+size+' --ext='+ext+' -n '+str(n)
	if rebuild:
		cmd += ' --rebuild'
	cmd += ' '+bench

	os.system(cmd)

for bmk in to_run:
	if size == 'default':
		if bmk in train_benchmarks:
			this_size = 'train'
		else:
			this_size = 'test'
	else:
		this_size = size

	for config in run_configs:
		if config == 'link':
			for i in range(0, iterations):
				runspec(bmk, this_size, tune, 'link', 1, rebuild=True)
		else:
			runspec(bmk, this_size, tune, config, iterations)

