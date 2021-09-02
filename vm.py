#!/usr/bin/env python3

import sys
from array import array

# Program counter
pc = 0

def add     (): b = pop(); a = pop(); push(a + b)
def sub     (): b = pop(); a = pop(); push(a - b)
def mul     (): b = pop(); a = pop(); push(a * b)
def div     (): b = pop(); a = pop(); push(a // b)
def mod     (): b = pop(); a = pop(); push(a % b)
def drop    (): pop()
def swap    (): ps[-1], ps[-2] = ps[-2], ps[-1]
def nip     (): swap(); pop()
def dup     (): push(ps[-1])
def fetch   (): ps[-1] = mem[ps[-1]]
def store   () b = pop(); a = pop(); mem[a] = b
def give    (): sys.stdout.write(chr(pop()))
def take    (): push(ord(sys.stdout.read(1)))
def lit     (): ip += 1; push(mem[ip + 1])
def lit     (): ip += 1; push(mem[ip + 1])

# vim macro:
funcs = (

)

# Parameter Stack
ps = array('q')
def push (x): ps.append(x)
def pop (): return ps.pop()

# Return stack
rs = array('q')
def rpush (x): rs.append(x)
def rpop (): return rs.pop()

# Input file
try:
    program_name = sys.argv[1]
except IndexError:
    print(sys.argv[0], 'usage:', sys.argv[0], 'file')
    sys.exit(-1)
with open(program_name, 'rb') as program_file:
    program = program_file.read()

# Memory
mem = bytearray(program)

# Infinite execution loop
while 0 <= pc < len(mem):
    x = mem[pc]
    if x < num_free_bytes:
        # Non-opcode bytes are literal numbers
        push(x)
    else:
        # Opcode
        fn = funcs[x - num_free_bytes]
        fn()
    pc += 1

