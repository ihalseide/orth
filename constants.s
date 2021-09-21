	.equ F_IMMEDIATE, 0b10000000 // immediate word flag bit
	.equ F_HIDDEN,    0b01000000 // hidden word flag bit
	.equ F_COMPILE,   0b00100000 // compile-only word flag bit
	.equ F_LENMASK,   0b00011111 // 31
	.equ TIB_SIZE, 1024          // (bytes) size of terminal input buffer
	.equ RSTACK_SIZE, 512*4      // (bytes) size of the return stack
	.equ STACK_SIZE, 64*4        // (bytes) size of the return stack

