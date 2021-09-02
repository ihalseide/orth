#!/usr/bin/env python3

import argparse, sys

p = argparse.ArgumentParser()
p.add_argument("file")
p.add_argument("-o", default=None, dest="outfile")
args = p.parse_args()

with open(args.file, "r") as file_in:
    if args.outfile is None:
        # Default output to stdout
        file_out = sys.stdout
    else:
        # Otherwise use the provided filename
        file_out = open(args.outfile, "w")
    for line in file_in.readlines():
        line = line.strip()
        if line == '': 
            # skip line that is all whitespace
            continue
        if line[0] == '\\':
            # skip line that is all comment
            continue
        # Remove comments
        line = line.split('\\')[0]
        paren_start = line.find('(')
        paren_end = line.find(')')
        if paren_start >= 0:
            if paren_end >= 0:
                line = line[:paren_start] + line[paren_end+1:]
            else:
                line = line[:paren_start]
        # Escape special characters
        line = line.replace('"', '\\"')
        # Add a space in front because the line separator
        # is removed and the language needs whitespace to
        # separate each word
        print('\t.ascii " %s"' % line, file=file_out)
    file_out.close()

