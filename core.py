#!/usr/bin/env python3

import sys

ip = 0 # Instruction pointer
stack = []
rstack = []
memory = []

def push (x: int):
    stack.append(x)
def pop () -> int:
    return stack.pop()
def pick (n) -> int:
    return stack[-n]
def top () -> int:
    return pick(-1)
def swap (i: int, j: int):
    stack[i], stack[j] = stack[j], stack[i]
def fetch (a: int) -> int:
    return memory[a]
def store (x: int, a: int):
    memory[a] = x
def mem_swap (i: int, j: int):
    memory[i], memory[j] = memory[j], memory[i]
def emit (x: int):
    c = chr(x)
    sys.stdout.write(c)
def getc () -> int:
    c = sys.stdin.read(1)
    return ord(c)
def rpush (x: int):
    rstack.append(x)
def rpop () -> int:
    return rstack.pop()
def tor ():
    rpush(pop())
def rfrom ():
    push(rpop())
def pnum (x: int):
    print(x, end=' ')

# Primitive operations/instructions
def _next ():
    global ip
    ip += 1
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
    emit(pop())
def _getc ():
    push(getc())
def _exit ():
    global ip
    ip = rpop()
    _next()
def _branch ():
    ip += memory[ip+1]
def _0branch ():
    if pop() == 0:
        _branch()
def _execute ():
    x = pop()
    if x < len(ops):
        do_prim(x)
    else:
        do_call(x)
def _pnum ():
    pnum(pop())

# map str -> memory index
named = {
    'lit': 1,
    'getc': 2,
    'emit': 3,
    'drop': 4,
    'swap': 5,
    'dup': 6,
    'pick': 7,
    '+': 8,
    '-': 9,
    '*': 10,
    '/': 11,
    '@': 12,
    '!': 13,
    'exit': 14,
    'branch': 15,
    '0branch': 16,
    'execute': 17,
    'pnum': 18,
}

ops = [
    _noop,
    _lit, _getc, _emit,
    _drop, _swap, _dup, _pick,
    _add, _sub, _mul, _div,
    _fetch, _store,
    _exit,
    _branch,
    _0branch,
    _execute,
    _pnum,
]

def do_prim (inst: int):
    # Primitive operation
    fn = ops[inst]
    fn()
    _next()

def do_call (a: int):
    global ip
    rpush(ip)
    ip = a

def main ():
    global ip, memory
    prog = input().split()
    use = lambda x: named[x] if x in named else int(x)
    memory = [use(x) for x in prog]
    print('translated to: ', memory)
    print('running...')
    while ip < len(memory):
        x = memory[ip]
        if x < len(ops):
            do_prim(x)
        else:
            do_call(x)

if __name__ == '__main__':
    main()

