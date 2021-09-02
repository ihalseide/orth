#!/usr/bin/env python3

import sys
from array import array

# Helper functions:

def add_builtin (name, fn):
    i = len(builtins)
    builtins.append(fn)
    word_dict[name] = i

def push (x: int):
    stack.append(x)

def pop () -> int:
    return stack.pop()

def pick (n) -> int:
    return stack[-n]

def top () -> int:
    return pick(-1)

def fetch (a: int) -> int:
    return memory[a]

def store (x: int, a: int):
    memory[a] = x

def rpush (x: int):
    rstack.append(x)

def rpop () -> int:
    return rstack.pop()

# Built-in operations/instructions:

# [enter|address]
#   ^
#   |_ ip
def _enter ():
    global ip
    rpush(ip+2) # return to the next instruction, not the literal address value
    ip = memory[ip+1]

def _tor ():
    rpush(pop())

def _rfrom ():
    push(rpop())

def _lit ():
    global ip
    push(memory[ip+1])
    ip += 1

def _noop ():
    pass

def _drop ():
    stack.pop()

def _dup ():
    push(top())

def _swap ():
    x = pop()
    y = pop()
    push(x)
    push(y)

def _pick ():
    push(pick(pop()))

def _add ():
    push(pop() + pop())

def _sub ():
    push(pop() - pop())

def _mul ():
    push(pop() * pop())

def _div ():
    push(pop() // pop())

def _fetch ():
    push(fetch(pop()))

def _store ():
    store(pop(), pop())

def _emit ():
    c = chr(pop())
    sys.stdout.write(c)

def _getc ():
    c = sys.stdin.read(1)
    push(ord(c))

def _exit ():
    global ip
    ip = rpop()

def _branch ():
    ip += memory[ip+1]

def _0branch ():
    if pop() == 0:
        _branch()

def _execute ():
    x = pop()
    if x < len(builtins):
        do_builtin(x)
    else:
        do_enter(x)

def _pnum ():
    print(pop())

def _stop ():
    ip = len(memory)
    print("[STOP]")

# Instruction pointer in memory
ip = 0
# Compilation pointer in memory
h = 0
# Parameter/data stack
stack = array('q')
# Return stack
rstack = array('q')
# Program memory (and code)
memory = array('q')
# Map str to indices in the memory[]
word_dict = {}
# List of functions
builtins = []

# Add all the builtins
add_builtin('noop', _noop)
add_builtin('+', _add)
add_builtin('-', _sub)
add_builtin('*', _mul)
add_builtin('/', _div)
add_builtin('branch', _branch)
add_builtin('0branch', _0branch)
add_builtin('emit', _emit)
add_builtin('getc', _getc)
add_builtin('lit', _lit)
add_builtin('enter', _enter)
add_builtin('exit', _exit)
add_builtin('stop', _stop)
add_builtin('.', _pnum) # debug

# Get program input
prog = ''
while (s := input()):
    prog += ' ' + s
words = prog.split()
convert = lambda x: word_dict[x] if (x in word_dict) else int(x)
memory = array('q', [convert(x) for x in words]+[0 for x in range(16)])
print('words:', words)
print('memory:', memory)
print('running...')

# Execute
while ip < len(memory):
    x = memory[ip]
    try:
        fn = builtins[x]
        fn()
    except IndexError:
        print('ip=', x, 'out of range')
        break
    ip += 1

