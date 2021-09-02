#!/usr/bin/env python3

import sys

ip = 0 # Instruction pointer
stack = []
memory = [0, 42, 1, 0, 43, 1, 0, 44, 1]

def push (x: int):
    stack.append(x)
def pop () -> int:
    return stack.pop()
def pick (n) -> int:
    return stack[-n]
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

###

def _lit ():
    global ip
    push(memory[ip+1])
    ip += 1
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

def do_primitive (inst: int):
    global ip
    fn = [
        _lit, _emit,
        _drop, _swap, _dup, _pick,
        _add, _sub, _mul, _div,
        _fetch, _store
    ][inst]
    fn()
    ip += 1

def do_call (a: int):
    global ip
    ip = a

def main ():
    global ip
    while ip < len(memory):
        x = memory[ip]
        if x < 10:
            do_primitive(x)
        else:
            do_call(x)

main()

