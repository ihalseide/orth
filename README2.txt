= My forth for Raspberry Pi, ARM v71 =

Forth in assembler language by Izak Nathanael Halseide

== System Features ==

* spaces are the only non-word character
* buffered input
* immediate mode: run code at compile time
* word headers only guaranteed at compile time
** challenge: how to variables and constants? see C?
* word headers include name, source code, and compiled code
* words can have names up to a 31-characters long
* compile ARM code
* save word headers at run time only if desired

== Library Features ==

* music synthesis
* arrays
* file I/O

== Word header structure ==

 struct WordHeader {
     struct WordHeader * link;
     struct {
         char len_flags;  // binary: ffflllll
         char name[31];
     } name;
     void * code_field;
     ExecutionToken params[];
 };

== Assembly Code ==

Forth Implementation in ARMv7 assembly for GNU/Linux eabi by Izak Nathanael
Halseide. This is an indirect threaded forth. The top of the parameter stack
is stored in register R9. The parameter stack pointer (PSP) is stored in
register R13. The parameter stack grows downwards. The return stack pointer
(RSP) is stored in register R11. The return stack grows downwards. The forth
virtual instruction pointer (IP) is stored in register R10. The address of the
current execution token (XT) is stored in register R8.

