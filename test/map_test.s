	.text
	.global main
main:
	/* r0 = argc = number of command-line arguments in Linux */
	sub r0, #1    /* subtract 1 because you can't pass 0 args */

	/* Test code:
	 * Math "r9 = (r9 + r9) - 1" will map 1 to 1, and map 0 to -1.
	 */
	add r0, r0             
	sub r0, #1

	/* End of test code. */
	bx lr

