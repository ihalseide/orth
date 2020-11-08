\ This is rest of FemtoForth written in itself. No more assembly!

\ Redefine version based on how updated this file is
: VERSION 2 ;

\ Create standard shortcuts for System Calls with a certain number of arguments
\ Also, redefine SYSCALL to do nothing now so that making syscalls with too many 
\ parameters isn't easy.
\ (Only syscalls with 0-3 parameters are allowed, at least on ARM chips)
: SYSCALL0 0 SYSCALL ;
: SYSCALL1 1 SYSCALL ;
: SYSCALL2 2 SYSCALL ;
: SYSCALL3 3 SYSCALL ;
: SYSCALL ;

\ Halt and exit the whole FemtoForth program 
: HALT 0 SYS_EXIT SYSCALL1 ;

\ Comparison and Boolean values
: TRUE -1 ;
: FALSE 0 ;
: 0= 0 = ;
: NOT 0= ;
: <= > NOT ;
: >= < NOT ; 
: 0> 0 > ;
: 0< 0 < ;
: 0<= 0 <= ;
: 0>= 0 >= ;
: 0!= 0= NOT ;

\ Incrementation shortcuts
: 1+ 1 + ;
: 1- 1 - ;
: 4+ 4 + ;
: 4- 4 - ; 

\ Negate a number
: NEGATE 0 SWAP - ;

\ Use the DIVMOD operation defined in assembly
\ in order to create DIV and MOD
: / /MOD SWAP DROP ; 
: MOD /MOD DROP ;

\ Whitespace character constants
: BL 32 ;
: '\n' 10 ; 
: '\t' 9 ;

\ Character emitters
: SPACE BL EMIT ;
: CR '\n' EMIT ;
: TAB '\t' EMIT ;

\ LITERAL takes whatever is on the stack and compiles it to <LIT _x_>
: LITERAL ' LIT , , ;
IMMEDIATE

\ Use LITERAL to define character constants devised at compile-time
: '(' [ CHAR ( ] LITERAL ;
: ')' [ CHAR ) ] LITERAL ;
: ':' [ CHAR : ] LITERAL ;
: ';' [ CHAR ; ] LITERAL ;
: '.' [ CHAR . ] LITERAL ;

\ When in compile mode, [COMPILE] is used to compile the next word even if it is
\ an immediate word.
: [COMPILE] WORD FIND >CFA , ;
IMMEDIATE

: RECURSE LATEST @ >CFA , ;
IMMEDIATE

\ Define the IF/THEN/ELSE construct
: IF ' 0BRANCH , HERE @ 0 , ; IMMEDIATE 
: THEN DUP HERE @ SWAP - SWAP ! ; IMMEDIATE 
: ELSE
	' BRANCH ,
	HERE @
	0 ,
	SWAP DUP
	HERE @ SWAP -
	SWAP ! ;
IMMEDIATE

: .OK .S"  ok." CR ;

: .HELLO
	.S" FemtoForth version " VERSION . '.' EMIT CR
	.OK ;

.HELLO
HIDE .HELLO
