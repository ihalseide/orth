# Orth

My (always unfinished) forth for Raspberry Pi, ARM v71

Note: Raspberry Pi Resource [https://github.com/dwelch67/raspberrypi]

## Implementation notes

* This is an indirect threaded forth.
* The top of the parameter stack is stored in register R9. The parameter stack pointer (PSP) is stored in register R13.
* The parameter stack grows downwards.
* The return stack pointer (RSP) is stored in register R11.
* The return stack grows downwards.
* The forth virtual instruction pointer (IP) is stored in register R10.
* The address of the current execution token (XT) is stored in register R8.

