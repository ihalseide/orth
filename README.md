# Orth

My forth for Raspberry Pi, ARM v71

## System Features

* buffered input
* immediate mode: run code at compile time
* word headers include name, source code, and compiled code
* words can have names up to a 31-characters long

## Word header structure

 struct WordHeader {
     struct WordHeader * link;
     struct {
         char len_flags;  // binary: ffflllll
         char name[31];
     } name;
     void * code_field;
     ExecutionToken params[];
 };

## Assembly Code

This is an indirect threaded forth.
The top of the parameter stack is stored in register R9. The parameter stack pointer (PSP) is stored in register R13.
The parameter stack grows downwards.
The return stack pointer (RSP) is stored in register R11.
The return stack grows downwards.
The forth virtual instruction pointer (IP) is stored in register R10.
The address of the current execution token (XT) is stored in register R8.

## Stack Comments

Enclosed in parantheses. E.G: "( x1 x2 -- a )". Rightmost text is topmost item on the stack.

The "--" means after the word is executed.

A "R:" means the return stack effects

Stack item types:
* `x` any cell
* `n` signed number
* `u` unsigned number
* `d` double number (takes up two cells on stack)
breaks down into single cells of ( low-u high-n )
* `p` stands for "predicate", and is like `xt`, but the expected stack effect of the xt is ( i*x -- f )
* `xt` execution token, which is an executable address
* `a` address
* `i*x` items of type x, i number total

