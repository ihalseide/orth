My forth for Raspberry Pi, ARM v71 
by Izak Nathanael Halseide

Indirect threaded forth in assembler language

In ARM, a machine word = 4 bytes = 32 bits, and
In Linux on ARM eabi,
system calls store their return value in r0,
system calls are invoked with "swi #0",
system calls select the function that is called with the value in r7

These registers are reserved for specific use:
* r13 : data stack pointer (DSP). The stack grows downward
* r11 : return stack pointer (RSP). The stack grows downward
* r10 : virtual instruction pointer (IP)
* r9  : top of data stack value (TOS), which is not kept in the r13 data stack
* r8  : address of current execution token (XT), a.k.a.
        the code field address (CFA) of the current word being executed

Pushing and popping single registers to the data stack looks like this:
* push <reg> = str <reg>, [r13, #-4]!
* pop  <reg> = ldr <reg>, [r13], #4

Layout of a word definition:
* 4 bytes : link field. address of previous word
* 1 byte  : length field, also has a bit flag set if the word is immediate
* x bytes : name field. <length field> characters that make up the word's name
* 4 bytes : code field. contains the address of the executable code for the
            word, which can either be docol, dovar, doconst, or 
  	      the label/address of plain assembly code
* y bytes : data field. contains codewords for docol, assembly code,
            or data values for dovar and doconst

