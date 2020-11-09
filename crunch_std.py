#!/usr/bin/env python3

ifile = 'std.fth'
ofile = 'std.crunch.fth'

print("Crunching '%s' down into '%s'"%(ifile,ofile))

with open(ifile) as infile:
	with open(ofile, "w+") as ofile:
		for line in infile:
			if line and line.strip() and not line[0] == '\\':
				ofile.write(' '.join(line.replace('\t',' ').split())+'\n')

print("Done.")

