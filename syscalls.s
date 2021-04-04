// System calls

syscall0:
	mov r7, r9         ; get the syscall id from TOS
	swi #0             ; syscall()
	mov r9, r0         ; set TOS to the return value
	b next


syscall1:
	mov r7, r9   // get the syscall id from TOS
	pop {r0}     // get the 1st arg from stack
	swi #0       // syscall()
	mov r9, r0   // set TOS to the return value
	b next


syscall2:
	mov r7, r9   // get the syscall id from TOS
	pop {r0}     // get the 1st arg from stack
	pop {r1}     // get the 2nd arg from stack
	swi #0       // syscall()
	mov r9, r0   // set TOS to the return value
	b next


syscall3:
	mov r7, r9   // get the syscall id from TOS
	pop {r0}     // get the 1st arg from stack
	pop {r1}     // get the 2nd arg from stack
	pop {r2}     // get the 3rd arg from stack
	swi #0       // syscall()
	mov r9, r0   // set TOS to the return value
	b next


syscall4:
	mov r7, r9   // get the syscall id from TOS
	pop {r0}     // get the 1st arg from stack
	pop {r1}     // get the 2nd arg from stack
	pop {r2}     // get the 3rd arg from stack
	pop {r3}     // get the 4th arg from stack
	swi #0       // syscall()
	mov r9, r0   // set TOS to the return value
	b next


syscall5:
	mov r7, r9   // get the syscall id from TOS
	pop {r0}     // get the 1st arg from stack
	pop {r1}     // get the 2nd arg from stack
	pop {r2}     // get the 3rd arg from stack
	pop {r3}     // get the 4th arg from stack
	pop {r4}     // get the 5th arg from stack
	swi #0       // syscall()
	mov r9, r0   // set TOS to the return value
	b next


syscall6:
	mov r7, r9   // get the syscall id from TOS
	pop {r0}     // get the 1st arg from stack
	pop {r1}     // get the 2nd arg from stack
	pop {r2}     // get the 3rd arg from stack
	pop {r3}     // get the 4th arg from stack
	pop {r4}     // get the 5th arg from stack
	pop {r5}     // get the 6th arg from stack
	swi #0       // syscall()
	mov r9, r0   // set TOS to the return value
	b next

