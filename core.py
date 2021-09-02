#!/usr/bin/env python3

import sys
from array import array

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
# List of defined words
word_dict = {}
# List of builtin functions
builtins = []

# Helper functions:

def add_builtin (name, fn):
    i = len(builtins)
    builtins.append(fn)
    word_dict[name] = i

def builtin (name):
    def decorate (fn):
        add_builtin(name, fn)
        return fn
    return decorate

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

def do_builtin (inst: int):
    # Primitive operation
    builtins[inst]()

def do_enter (a: int):
    global ip
    rpush(ip)
    ip = a

def do_next ():
    global ip
    ip += 1

# Built-in operations/instructions:

@builtin(">R")
def _tor ():
    rpush(pop())

@builtin("R>")
def _rfrom ():
    push(rpop())

@builtin('lit')
def _lit ():
    global ip
    push(memory[ip+1])
    ip += 1

@builtin('noop')
def _noop ():
    pass

@builtin('drop')
def _drop ():
    stack.pop()

@builtin('dup')
def _dup ():
    push(top())

@builtin('swap')
def _swap ():
    x = pop()
    y = pop()
    push(x)
    push(y)

@builtin('pick')
def _pick ():
    push(pick(pop()))

@builtin('+')
def _add ():
    push(pop() + pop())

@builtin('-')
def _sub ():
    push(pop() - pop())

@builtin('*')
def _mul ():
    push(pop() * pop())

@builtin('/')
def _div ():
    push(pop() // pop())

@builtin('@')
def _fetch ():
    push(fetch(pop()))

@builtin('!')
def _store ():
    store(pop(), pop())

@builtin('emit')
def _emit ():
    c = chr(pop())
    sys.stdout.write(c)

@builtin('getc')
def _getc ():
    c = sys.stdin.read(1)
    push(ord(c))

@builtin('exit')
def _exit ():
    global ip
    ip = rpop()

@builtin('branch')
def _branch ():
    ip += memory[ip+1]

@builtin('0branch')
def _0branch ():
    if pop() == 0:
        _branch()

@builtin('execute')
def _execute ():
    x = pop()
    if x < len(builtins):
        do_builtin(x)
    else:
        do_enter(x)

@builtin('.')
def _pnum ():
    print(pop())

@builtin('stop')
def _stop ():
    ip = len(memory)
    print("[STOP]")

def main ():
    global ip, memory

    # Get program input
    prog = ''
    while (s := input()):
        prog += s
    words = prog.split()
    convert = lambda x: word_dict[x] if (x in word_dict) else int(x)
    memory = array('q', [convert(x) for x in words]+[0 for x in range(16)])
    print('words:', words)
    print('memory:', memory)
    print('running...')

    # Execute
    while ip < len(memory):
        x = memory[ip]
        if x < len(builtins):
            do_builtin(x)
        else:
            do_enter(x)

if __name__ == '__main__':
    main()

