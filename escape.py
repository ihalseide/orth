#!/usr/bin/env python3

def chr_escape (ch):
	if '\\' == ch: # 1 backslash
		return r'\\' # 2 actual backslashes
	elif '\n' == ch:
		return "\\n"
	elif '"' == ch:
		return "\""
	elif '\r' == ch:
		return "\\r"
	elif '\t' == ch:
		return "\\t"
	else:
		return ch

def str_escape (string):
	result = ''
	for char in string:
		result += chr_escape(char)
	return result

def asm_str (string):
	return '\t.ascii "{}"'.format(str_escape(string))

import argparse

p = argparse.ArgumentParser()
p.add_argument("file")
args = p.parse_args()

# Print the prologue, which is just the section/label
print("forth_src:")
# Escape each line from the file
with open(args.file, "r") as file:
	for line in file.readlines():
		if line[0] == '\\': # Skip lines that begin with a backslash
			continue
		if not line.strip():
			continue
		print(asm_str(line))

