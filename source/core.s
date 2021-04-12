// Forth Implementation in ARMv7 assembly for GNU/Linux eabi
// by Izak Nathanael Halseide
// Notes:
// * This is an indirect threaded forth.
// * The top of the parameter stack is stored in register R9
// * The parameter stack pointer (PSP) is stored in register R13
// * The parameter stack grows downwards
// * The return stack pointer (RSP) is stored in register R11
// * The return stack grows downwards.
// * The forth virtual instruction pointer (IP) is stored in register R10.
// * The address of the current execution token (XT) is usually stored in register R8
// * Variables that are accessed in both assembly and forth have to go through 2 layers of indirection to be accessed directly in assembly code. One layer is the forth variable layer, and the other is the assembler literal pool

	.section .init

	.global _start
_start:
	mov sp, #0x8000            // stack grows down from address 0x8000
loop:
	b loop

