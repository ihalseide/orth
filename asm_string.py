#!/usr/bin/env python3

import argparse

def esc (s):
    s = s.replace('\\','\\\\')\
         .replace('\n', '\\n')\
         .replace('"','\\"')\
         .replace('\t','\\t')
    return s

p = argparse.ArgumentParser()
p.add_argument("file")
p.add_argument("-o", default="a.out", dest="outfile")
args = p.parse_args()

with open(args.file, "r") as file_in:
    with open(args.outfile, "w") as file_out:
        for line in file_in.readlines():
            print('\t.ascii "%s"' % esc(line), file=file_out)

