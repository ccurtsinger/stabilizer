#!/usr/bin/env python

import sys
import argparse
from numpy import mean, median, std, histogram
from scipy.stats import shapiro, anderson

parser = argparse.ArgumentParser(description='SPEC CPU2006 Output File Processor')
parser.add_argument('-norm', action='store_true')
parser.add_argument('-range', action='store_true')
parser.add_argument('-len', action='store_true')
parser.add_argument('-r', action='store_true')
parser.add_argument('-trim', action='store_true')
parser.add_argument('-all', action='store_true')
parser.add_argument('-ext', choices=['code', 'code.stack', 'code.heap.stack', 'link'], default=False)
parser.add_argument('-tune', choices=['base', 'peak'], default=False)
parser.add_argument('files', nargs='+')

args = parser.parse_args()

if args.ext == False:
	args.ext = ['code', 'code.stack', 'code.heap.stack', 'link']
else:
	args.ext = [args.ext]

if args.tune == False:
	args.tune = ['base', 'peak']
else:
	args.tune = [args.tune]

results = []

for filename in args.files:
	f = open(filename, 'r')
	
	bits = {}
	
	for line in f:
		if line.startswith('spec.cpu2006.results'):
			(s, c, r, bmk, tune, n, key_value) = line.split('.', 6)
			(key, value) = key_value.split(':', 1)

			(ignore, bmk) = bmk.split('_')
		
			if bmk not in bits:
				bits[bmk] = {}
			
			if n not in bits[bmk]:
				bits[bmk][n] = {}
			
			bits[bmk][n]['tune'] = tune
			bits[bmk][n][key.strip()] = value.strip()
	
	for bmk in bits:
		for n in bits[bmk]:
			results.append(bits[bmk][n])

def where(results, key, *values):
	return filter(lambda r: r[key] in values, results)

def distinct(results, key):
	values = []
	for r in results:
		if r[key] not in values:
			values.append(r[key])
	return values

def keymap(results, key, f):
	next_results = []
	for r in results:
		next_r = dict(r)
		next_r[key] = f(r[key])
		next_results.append(next_r)
	return next_results

def get(results, *keys):
	next_results = []
	for r in results:
		next_r = {}
		for k in r:
			if k in keys:
				next_r[k] = r[k]
		next_results.append(next_r)
	return next_results

def group(results, *keys):
	if len(keys) == 0:
		return results
	
	key = keys[0]
	grouped = {}
	for r in results:
		if r[key] not in grouped:
			grouped[r[key]] = []
		
		new_r = dict(r)
		del new_r[key]
		
		if len(new_r) == 1:
			new_r = new_r.values()[0]
		
		grouped[r[key]].append(new_r)
	
	for g in grouped:
		grouped[g] = group(grouped[g], *keys[1:])
	return grouped

def pad(s, length=20):
	if len(s) < length:
		return s + ' '*(length - len(s))
	else:
		return s[0:length]

results = where(results, 'valid', 'S')
results = get(results, 'benchmark', 'tune', 'reported_time', 'ext')

results = keymap(results, 'benchmark', lambda b: b.split('.')[1])
results = keymap(results, 'reported_time', float)

exts = distinct(results, 'ext')
tunes = distinct(results, 'tune')
benchmarks = distinct(results, 'benchmark')

results = group(results, 'benchmark', 'tune', 'ext')

if args.trim:
	for benchmark in results:
		for tune in results[benchmark]:
			for ext in results[benchmark][tune]:
				values = results[benchmark][tune][ext]
				hi = max(values)
				lo = min(values)
				del values[values.index(hi)]
				del values[values.index(lo)]
				results[benchmark][tune][ext] = values

#if args.r:
#	for benchmark in results:
#		sets = []
#		for tune in results[benchmark]:
#			for ext in results[benchmark][tune]:
#				name = benchmark+'_'+tune+'_'+ext.replace('.', '_')
#				values = results[benchmark][tune][ext]
#				print name+' = c('+', '.join(map(str, values))+')'
#				sets.append('"'+ext.replace('.', '_')+'"='+name)
#		print benchmark+' <- list(' + ', '.join(sets) + ')'

if args.r:
	benchmarks = []
	tunes = []
	exts = []
	times = []

	for benchmark in results:
		for tune in results[benchmark]:
			if tune in args.tune:
				for ext in results[benchmark][tune]:
					if ext in args.ext:
						for time in results[benchmark][tune][ext]:
							benchmarks.append('"'+benchmark+'"')
							tunes.append('"'+tune+'"')
							exts.append('"'+ext+'"')
							times.append(str(time))

	print 'dat <- data.frame(benchmark=c(' + ', '.join(benchmarks) + '), tune=c(' + ', '.join(tunes) + '), ext=c(' + ', '.join(exts) + '), time=c(' + ', '.join(times) + '))'

		
elif args.all:
	benchmarks.sort()
	tunes.sort()
	exts.sort()
	
	for tune in tunes:
		if tune in args.tune:
			for benchmark in benchmarks:
				for ext in exts:
					if ext in args.ext:
						if tune in results[benchmark] and ext in results[benchmark][tune]:
							row = [benchmark+'_'+ext+'_'+tune]
							row += results[benchmark][tune][ext]
							print ', '.join(map(str, row))
	
else:
	benchmarks.sort()
	tunes.sort()
	exts.sort()
	
	headings = ['Benchmark']
	columns = []
	for ext in exts:
		if ext in args.ext:
			for tune in tunes:
				if tune in args.tune:	
					found = False
					for benchmark in benchmarks:
						found |= tune in results[benchmark] and ext in results[benchmark][tune]
						
					if found:
						headings.append(ext+'_'+tune)
						columns.append(ext+'_'+tune)
	
	print ', '.join(map(pad, headings))
	
	for benchmark in benchmarks:
		print pad(benchmark)+',',
	
		values = []
		for ext in exts:
			if ext in args.ext:
				for tune in tunes:
					if tune in args.tune:
						if (ext+'_'+tune) in columns:
							if (tune not in results[benchmark] or ext not in results[benchmark][tune]):
								values.append('')
							elif args.norm:
								if len(results[benchmark][tune][ext]) < 3:
									values.append('')
								else:
									(k2, p) = shapiro(results[benchmark][tune][ext])
									values.append(p > 0.05)
									#(A2, critical, sig) = anderson(results[benchmark][ext])
									#values.append(A2 <= critical[1])
							elif args.range:
								avg = mean(results[benchmark][tune][ext])
								up = max(results[benchmark][tune][ext]) - avg
								down = avg - min(results[benchmark][tune][ext])
								values.append(max(up / avg, down / avg))
							elif args.len:
								values.append(len(results[benchmark][tune][ext]))
							else:
								values.append(mean(results[benchmark][tune][ext]))
	
		print ', '.join(map(pad, map(str, values)))
