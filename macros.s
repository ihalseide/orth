
	// Push to return stack
	.macro rpush reg
		str \reg, [r11, #-4]!
	.endm

	// Pop from return stack
	.macro rpop reg
		ldr \reg, [r11], #4
	.endm

	// The inner interpreter
	.macro NEXT
		ldr r8, [r10], #4 // r10 = the virtual instruction pointer
		ldr r0, [r8]      // r8 = xt of current word
		bx r0             // (r0 = temp)
	.endm

	// Define an assembly word
	.set link, 0
	.macro defcode name, len, label, flags=0
	.data
	.align 2                 // link field
def_\label:
	.int link
	.set link, def_\label
	.byte \len+\flags         // name field
	.ascii "\name"
	.space F_LENMASK-\len
	.align 2
xt_\label:                   // code field
	.int code_\label
	.text                    // start defining the code after the macro
	.align 2
	code_\label:
	.endm

	// Define a high-level word (indirect threaded)
	.macro defword name, len, label, flags=0
	.data
	.align 2              // link field
def_\label:
	.int link
	.set link, def_\label
	.byte \len+\flags     // name field
	.ascii "\name"
	.space F_LENMASK-\len
	.align 2
	.global xt_\label
xt_\label:                // xt: colon interpreter
	.int enter_colon
	params_\label:            // parameters
	.endm

	// Label for relative branches within "defword" macros
	.macro label name
		.int \name - .
	.endm

