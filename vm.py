#!/usr/bin/env python3

import sys
from array import array

# Program counter
pc = 0

# Opcodes
def noop  (): pass
def add   (): b = pop(); a = pop(); push(a + b)
def sub   (): b = pop(); a = pop(); push(a - b)
def mul   (): b = pop(); a = pop(); push(a * b)
def div   (): b = pop(); a = pop(); push(a // b)
def mod   (): b = pop(); a = pop(); push(a % b)
def drop  (): pop()
def swap  (): ps[-1], ps[-2] = ps[-2], ps[-1]
def nip   (): swap(); pop()
def dup   (): push(ps[-1])
def cfetch(): ps[-1] = mem[ps[-1]]
def cstore(): b = pop(); a = pop(); mem[a] = b
def give  (): sys.stdout.write(chr(pop()))
def take  (): push(ord(sys.stdin.read(1)))
def lit   (): global pc; pc += 1; push(mem[pc])
def equ   (): b = pop(); a = pop(); push(int(a == b))
def lt    (): b = pop(); a = pop(); push(int(b < a))
def gt    (): b = pop(); a = pop(); push(int(b > a))
def neg   (): ps[-1] = -ps[-1]
def not_  (): ps[-1] = ~ps[-1]
def and_  (): b = pop(); a = pop(); push(a & b)
def or_   (): b = pop(); a = pop(); push(a | b)
def xor_  (): b = pop(); a = pop(); push(a ^ b)
def branch(): global pc; a = mem[pc + 1]; pc += a
def maybe (): global pc; pc += (0 if pop() else 1)
def halt  (): sys.exit(0)
def tor   (): rpush(pop())
def fromr (): push(rpop())
def mswap (): b = pop(); a = pop(); mem[a], mem[b] = mem[b], mem[a]

# vim macro: 0dwe C,j
funcs = (
    noop,
    add,
    sub,
    mul,
    div,
    mod,
    drop,
    swap,
    nip,
    dup,
    cfetch,
    cstore,
    give,
    take,
    lit,
    equ,
    lt,
    gt,
    neg,
    not_,
    and_,
    or_,
    xor_,
    branch,
    maybe,
    halt,
    tor,
    fromr,
    mswap,
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
    fn = funcs[x]
    fn()
    pc += 1

