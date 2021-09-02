#!/usr/bin/env python3

import sys
from array import array

class VM:

    funcs = tuple()

    def __init__(self, memory: bytearray):
        # Program counter
        self.pc: int = 0
        # Memory bytes
        self.mem: bytearray = memory
        # Parameter Stack
        self.ps = array('q')
        # Return stack
        self.rs = array('q')

    def run(self):
        while 0 <= self.pc < len(self.mem):
            self.step()

    def steps(self, n):
        while n > 0 and(0 <= self.pc < len(self.mem)):
            self.step()
            n -= 1

    def step(self):
        x = self.mem[self.pc]
        fn = self.funcs[x]
        fn(self)
        self.pc += 1

    def rpush(self, x):
        self.rs.append(x)

    def rpop(self):
        return self.rs.pop()

    def push(self, x):
        self.ps.append(x)

    def pop(self):
        return self.ps.pop()

    # Opcodes
    def noop(self):
        pass

    def add(self):
        b = self.pop()
        a = self.pop()
        self.push(a + b)

    def sub(self):
        b = self.pop()
        a = self.pop()
        self.push(a - b)

    def mul(self):
        b = self.pop()
        a = self.pop()
        self.push(a * b)

    def div(self):
        b = self.pop()
        a = self.pop()
        self.push(a // b)

    def mod(self):
        b = self.pop()
        a = self.pop()
        self.push(a % b)

    def drop(self):
        self.pop()

    def swap(self):
        self.ps[-1], self.ps[-2] = self.ps[-2], self.ps[-1]

    def nip(self):
        self.swap()
        self.pop()

    def dup(self):
        self.push(self.ps[-1])

    def cfetch(self):
        self.ps[-1] = self.mem[self.ps[-1]]

    def fetch(self):
        a = ps[-1]
        self.ps[-1] = int.from_bytes(self.mem[a:a+4])

    def cstore(self):
        b = self.pop()
        a = self.pop()
        self.mem[b] = a

    def store(self):
        b = self.pop()
        a = self.pop()
        self.mem[b:b+4] = a.to_bytes(4)

    def give(self):
        sys.stdout.write(chr(self.pop()))

    def take(self):
        self.push(ord(sys.stdin.read(1)))

    def litc(self):
        # Literal char/byte
        self.pc += 1
        self.push(self.mem[self.pc])

    def lit(self):
        self.pc += 4
        self.push(int.from_bytes(self.mem[self.pc:self.pc+4], byteorder='big'))

    def equ(self):
        b = self.pop()
        a = self.pop()
        self.push(int(a == b))

    def lt(self):
        b = self.pop()
        a = self.pop()
        self.push(int(b < a))

    def gt(self):
        b = self.pop()
        a = self.pop()
        self.push(int(b > a))

    def neg(self):
        self.ps[-1] = -self.ps[-1]

    def not_(self):
        self.ps[-1] = ~self.ps[-1]

    def and_(self):
        b = self.pop()
        a = self.pop()
        self.push(a & b)

    def or_(self):
        b = self.pop()
        a = self.pop()
        self.push(a | b)

    def xor_(self):
        b = self.pop()
        a = self.pop()
        self.push(a ^ b)

    def branch(self):
        a = self.mem[self.pc + 1]
        self.pc += a

    def maybe(self):
        self.pc +=(0 if self.pop() else 1)

    def halt(self):
        sys.exit(0)

    def tor(self):
        self.rpush(self.pop())

    def fromr(self):
        self.push(self.rpop())

    def mswap(self):
        b = self.pop()
        a = self.pop()
        self.mem[a], self.mem[b] = self.mem[b], self.mem[a]

VM.funcs =(
    VM.rpush,
    VM.rpop,
    VM.push,
    VM.pop,
    VM.noop,
    VM.add,
    VM.sub,
    VM.mul,
    VM.div,
    VM.mod,
    VM.drop,
    VM.swap,
    VM.nip,
    VM.dup,
    VM.cfetch,
    VM.fetch,
    VM.cstore,
    VM.store,
    VM.give,
    VM.take,
    VM.litc,
    VM.lit,
    VM.equ,
    VM.lt,
    VM.gt,
    VM.neg,
    VM.and_,
    VM.or_,
    VM.xor_,
    VM.branch,
    VM.maybe,
    VM.halt,
    VM.tor,
    VM.fromr,
    VM.mswap,
)

if __name__ == '__main__':
    fns = (
        VM.litc, 42,
        VM.give,
        VM.halt,
    )
    #print(fns)
    b = bytearray([VM.funcs.index(x) if (x in VM.funcs) else int(x) for x in fns])
    #print(b)
    v = VM(b)
    v.run()

