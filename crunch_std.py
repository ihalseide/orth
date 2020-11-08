#!/usr/bin/env python3
print("Crunching 'std.fth' down into 'std.cruch.fth'")

with open("std.fth") as infile:
	with open("std.crunch.fth", "w+") as ofile:
		for line in infile:
			if line and line.strip() and not line[0] == '\\':
				ofile.write(' '.join(line.replace('\t',' ').split())+'\n')

print("Done.")

