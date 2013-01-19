#!/usr/bin/env python

import os
import sys

benchmarks = ['astar', 'bwaves', 'bzip2', 'cactusADM', 'calculix', 'gcc', 'gobmk', 'gromacs', 'h264ref', 'hmmer', 'lbm', 'leslie3d', 'libquantum', 'mcf', 'milc', 'namd', 'perlbench', 'sjeng', 'sphinx3', 'wrf', 'zeusmp']

iterations = 10
to_run = []
dont_run = []
configs = ['code', 'code.stack', 'code.heap.stack', 'stack', 'heap.stack', 'heap', 'link']
tune = 'O2'
size = 'train'
run_configs = []

for arg in sys.argv[1:]:
	if arg in benchmarks:
		to_run.append(arg)
	elif arg.startswith('-') and arg[1:] in benchmarks:
		dont_run.append(arg[1:])
	elif arg in configs:
		run_configs.append(arg)
	elif arg in ['O0', 'O1', 'O2', 'O3']:
		tune = arg
	elif arg in ['test', 'train', 'ref']:
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

def runspec(bench, size, tune, ext, n, rebuild=False):
	if tune == 'O0' or tune == 'O1':
		real_config = 'szclo'
	elif tune == 'O2' or tune == 'O3':
		real_config = 'szchi'
	
	if tune == 'O0' or tune == 'O2':
		real_tune = 'base'
	elif tune == 'O1' or tune == 'O3':
		real_tune = 'peak'
	
	cmd = 'runspec --config='+real_config+' --mach=linux --action=run --tune='+real_tune+' --size='+size+' --ext='+ext+' -n '+str(n)
	if rebuild:
		cmd += ' --rebuild'
	cmd += ' '+bench

	os.system(cmd)

for bmk in to_run:
	for config in run_configs:
		if config == 'link':
			for i in range(0, iterations):
				runspec(bmk, size, tune, 'link', 1, rebuild=True)
		else:
			runspec(bmk, size, tune, config, iterations, rebuild=True)

