\ This is rest of FemtoForth written in itself. No more assembly!

\ Create a null definition for STDLIB so that it can all be forgotten with FORGET later.
\ This would only be used by the user if they wanted to replace all further standard definitions.
: STDLIB ;

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
: TRUE 1 ;
: FALSE 0 ;
: 0= 0 = ;
: NOT 0= ;
: <> = NOT ;
: <= > NOT ;
: >= < NOT ; 
: 0> 0 > ;
: 0< 0 < ;
: 0<= 0 <= ;
: 0>= 0 >= ;
: 0<> 0= NOT ;

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
: '"' [ CHAR " ] LITERAL ; \ "<comment for syntax highlighting purposes only>
: '-' [ CHAR - ] LITERAL ;
: '0' [ CHAR 0 ] LITERAL ;
: 'A' [ CHAR A ] LITERAL ;

\ When in compile mode, [COMPILE] is used to compile the next word even if it is
\ an immediate word.
: [COMPILE] WORD FIND >CFA , ;
IMMEDIATE

: RECURSE LATEST @ >CFA , ;
IMMEDIATE

\ Define the IF/THEN/ELSE construct
\ UNLESS functions as the inverse of IF
: IF IMMEDIATE
	' 0BRANCH , HERE @ 0 , ; 
: UNLESS IMMEDIATE
	' NOT , [COMPILE] IF ;
: THEN IMMEDIATE
	DUP HERE @ SWAP - SWAP ! ;  
: ELSE IMMEDIATE
	' BRANCH ,
	HERE @
	0 ,
	SWAP DUP
	HERE @ SWAP -
	SWAP ! ;

\ Define the BEGIN <code> <condition> UNTIL construct
: BEGIN IMMEDIATE
	HERE @ ; 
: UNTIL IMMEDIATE
	' 0BRANCH , HERE @ - , ;

\ BEGIN <code> AGAIN construct
: AGAIN IMMEDIATE
	' BRANCH ,
	HERE @ - , ;

\ BEGIN <condition> WHILE <loop code> REPEAT
\ Compiles to: <condition> 0BRANCH <offset2> <loop code> BRANCH <offset>
: WHILE IMMEDIATE
	' 0BRANCH ,
	HERE @
	0 , ;
: REPEAT IMMEDIATE
	' BRANCH ,
	SWAP
	HERE @ - ,
	DUP
	HERE @ SWAP -
	SWAP ! ;

\ Allow ( ... ) as comments within function definitions
: ( IMMEDIATE
	1 \ Push depth, starting as 1
	BEGIN
		KEY DUP \ Get a character
		'(' = IF \ Open paren --> increase depth
			DROP 1+
		ELSE
			')' = IF \ Close paren --> decrease depth
				1-
			THEN
		THEN
	DUP 0= UNTIL \ Repeat until depth is 0
	DROP ; \ DROP depth counter

\ ( ... ) comments are now available

\ Words with more complex stack effects
: 2DROP ( x x -- ) DROP DROP ; 
: 2DUP ( x1 x2 -- x1 x2 x1 x2 ) OVER OVER ; 
: NIP ( x y -- y ) SWAP DROP ; 
: TUCK ( x y -- y x y ) SWAP OVER ; 
: PICK ( x_u ... x_1 x_0 u -- x_u ... x_1 x_0 x_u )
	1+ 4 *
	DSP@ + @ ; 

\ SPACES will print out n spaces. If n < 0, then no spaces are printed.
: SPACES ( n -- )
	BEGIN
		DUP 0> \ While n > 0
	WHILE
		SPACE 1- \ Print a space, and decrement
	REPEAT
	DROP ;
	
\ Words for manipulating the number BASE
: HEXADECIMAL ( -- )
	16 BASE ! ;
: DECIMAL ( -- )
	10 BASE ! ;
: BINARY ( -- )
	2 BASE ! ;
	
\ Print an unsigned number
: U#. ( u -- )
	BASE @ /MOD
	?DUP IF
		RECURSE
	THEN
	DUP 10 < IF
		'0'
	ELSE
		10 - 'A'
	THEN
	+ EMIT ;

\ Print out the stack, useful for debugging!
: #.S ( -- )
	DSP@
	BEGIN
		DUP S0 @ <
	WHILE
		DUP @ U#.
		SPACE
		4+
	REPEAT
	DROP ;

\ U#WIDTH returns the character width of an unsigned number in the current base
: U#WIDTH
	BASE @ /
	?DUP IF
		RECURSE 1+
	ELSE
		1
	THEN ;

\ U#.R prints an unsigned number padded to a certain character width
: U#.R ( u width -- )
	SWAP DUP
	U#WIDTH
	ROT SWAP -
	SPACES \ SPACES will only print if n is positive
	U#. ;

\ #.R prints a signed number padded to a certain width
: #.R ( n width -- )
	SWAP ( width n )
	DUP 0< IF
		NEGATE ( width u )
		\ Save a flag to remember the number was negative
		1 SWAP ROT ( 1 u width )
		- ( 1 u width-1 )

	ELSE
		0 SWAP ROT ( 0 u width )
	THEN
	SWAP DUP ( flag width u u )
	U#WIDTH ( flag width u uwidth )
	ROT SWAP - ( flag u width-uwidth )
	SPACES ( flag u )
	SWAP ( u flag )
	IF '-' EMIT THEN \ if it was negative, print the '-' sign
	U#. ;

\ Define #. to print out a number with a trailing space
: #.
	0 #.R
	SPACE ;

\ Redefine U#. to really print an unsigned number
: U#.
	U#. SPACE ;

\ `?' will fetch the number at an address and print it
: ? ( addr -- )
	@ #. ;

\ WITHIN 
: WITHIN ( c a b -- f) \ where f is a<=c<b
	-ROT
	OVER
	<= IF
		> IF TRUE
		ELSE FALSE
		THEN
	ELSE
		2DROP
		FALSE
	THEN ;

\ DEPTH returns the stack depth
: DEPTH ( -- n )
	S0 @ DSP@ -
	4- ;

\ Takes an address and rounds it up to the next 4-byte boundary
\ {addr+3 & ~3}
: ALIGNED ( addr -- addr )
	3 +
	3 ~ & ;

\ ALIGN aligns the address of the HERE pointer
: ALIGN
	HERE @ ALIGNED HERE ! ;

\ +! adds a value to the value in an address
: +! ( x addr -- )
	DUP ( x addr addr )
	@ ( x addr v )
	ROT + ( addr x+v )
	SWAP ( x+v addr )
	! ;

\ `C,' appends a byte to HERE
: C,
	HERE @ C!
	1 HERE +! ;

\ S" <string> " is used to define strings.
\ This word has to do different things depending on whether it is in compile or
\ in immediate mode.
\ In compile mode, we append the following to the current word:
\	LITSTRING <len> <string, rounded to 4-byte>
\ In immediate mode, the string is put at HERE, without modifying HERE.
: S" IMMEDIATE ( -- addr len )
	STATE @ IF \ Compile mode
		' LITSTRING ,
		HERE @
		0 ,
		BEGIN
			KEY
			DUP '"' <>
		WHILE
			C,
		REPEAT
		DROP
		DUP
		HERE @ SWAP -
		4-
		SWAP !
		ALIGN
	ELSE \ Immediate mode
		HERE @
		BEGIN
			KEY
			DUP '"' <>
		WHILE
			OVER C!
			1+
		REPEAT
		DROP
		HERE @ -
		HERE @
		SWAP
	THEN ;

\ ." is the print-string operator
: ." IMMEDIATE ( -- )
	STATE @ IF \ Compile mode
		[COMPILE] S"
		' TELL ,
	ELSE \ Immediate mode
		BEGIN
			KEY
			DUP '"' = IF
				DROP EXIT
			THEN
			EMIT
		AGAIN
	THEN ;

\ SKIPLINK is used to skip link pointers in word headers
: SKIPLINK 4+ ;

\ ID. takes a word dictionary address and prints the word's name
: ID. ( addr -- )
	SKIPLINK
	DUP C@ \ get flags and length byte
	F_LENMASK & \ get just the length
	BEGIN
		DUP 0>
	WHILE \ while length > 0
		SWAP 1+
		DUP C@
		EMIT
		SWAP 1-
	REPEAT
	2DROP ;

\ ?HIDDEN is used to return whether a word is hidden
\ Example: WORD <word> FIND ?HIDDEN
: ?HIDDEN ( addr -- flag )
	SKIPLINK
	C@ F_HIDDEN & ;

\ ?IMMEDIATE does what ?HIDDEN does, but for whether a word is marked immediate
: ?IMMEDIATE ( addr -- flag )
	SKIPLINK
	C@
	F_IMMED & ;

\ WORDS prints out all defined words, except for hidden ones
: WORDS ( -- )
	LATEST @
	BEGIN
		?DUP
	WHILE
		DUP ?HIDDEN NOT IF
			DUP ID.
			SPACE
		THEN
		@
	REPEAT
	CR ;

\ FORGET will deallocate memory by setting HERE to point to the word before the
\ given one.
\ Example: FORGET WORD will move HERE to be before WORD
: FORGET ( -- )
	WORD FIND
	DUP @
	LATEST !
	HERE ! ;

\ DUMP will print out the contents of memory as a hexdump
: DUMP
	BASE @ -ROT
	HEXADECIMAL
	BEGIN
		?DUP
	WHILE
		OVER 8 U#.R
		SPACE

		\ Print up to 16 words per line
		2DUP
		1- 15 & 1+ \ Note: should this really be "15", or should it be "E"???
		BEGIN
			?DUP
		WHILE
			SWAP
			DUP C@
			2 #.R SPACE
			1+ SWAP 1-
		REPEAT
		DROP

		2DUP 1- 15 & 1+ \ Note: should this really be "15", or should it be "E"???
		BEGIN
			?DUP
		WHILE
			SWAP
			DUP C@
			DUP 32 128 WITHIN IF
				EMIT
			ELSE
				DROP '.' EMIT
			THEN
			1+ SWAP 1-
		REPEAT
		DROP
		CR

		DUP 1- 15 & 1+ \ Note: should this really be "15", or should it be "E"???
		TUCK
		-
		>R + R>
	REPEAT
	DROP
	BASE ! ; \ Restore the saved base

\ Now for a non-trivial construct: CASE/ENDCASE
\ Example:
\	(with something on the stack to compare)
\	CASE
\	test1 OF ... ENDOF
\	test2 OF ... ENDOF
\	testn OF ... ENDOF
\	... (default)
\	ENDCASE
: CASE IMMEDIATE
	0 ;
: OF IMMEDIATE
	' OVER ,
	' = ,
	[COMPILE] IF
	' DROP , ;
: ENDOF IMMEDIATE
	[COMPILE] ELSE ;
: ENDCASE IMMEDIATE
	' DROP ,
	BEGIN
		?DUP
	WHILE
		[COMPILE] THEN
	REPEAT ;

\ Begin code for a FemtoForth decompiler...

\ CFA> is the opposite of >CFA. It takes a codeword inside the definition of
\ a word and tries to find the matching dictionary definition.
\ It returns 0 if it doesn't find a match.
: CFA>
	LATEST @
	BEGIN
		?DUP
	WHILE
		2DUP SWAP
		< IF
			\ Found, so leave current dictionary entry on the stack
			NIP
			EXIT
		THEN
		@
	REPEAT
	\ Nothing found
	DROP
	0 ;

\ SEE decompiles a Word
: SEE
	WORD FIND
	HERE @
	LATEST @
	BEGIN
		2 PICK
		OVER
		<>
	WHILE
		NIP
		DUP @
	REPEAT
	DROP SWAP
	\ Start printing out the source
	':' EMIT SPACE DUP ID. SPACE
	DUP ?IMMEDIATE IF ." IMMEDIATE " THEN

	>DFA

	BEGIN
		2DUP >
	WHILE
		DUP @
		CASE
			' LIT OF
				4 + DUP @
				.
				ENDOF
			' LITSTRING OF
				[ CHAR S ] LITERAL EMIT '"' EMIT SPACE
				4 + DUP @
				SWAP 4 + SWAP
				2DUP TELL
				'"' EMIT SPACE
				+ ALIGNED
				4 -
				ENDOF
			' 0BRANCH OF
				." 0BRANCH ( "
				4 + DUP @ #.
				." ) "
				ENDOF
			' BRANCH OF
				." BRANCH ( "
				4 + DUP @ #.
				." ) "
			' ' OF
				[ CHAR ' ] LITERAL EMIT SPACE
				4 + DUP @
				CFA>
				ID. SPACE
			ENDOF
			DUP
			CFA>
			ID. SPACE
		ENDCASE
		4 +
	REPEAT
	';' EMIT CR
	2DROP ;

\ :NONAME creates anonymous words. Execution tokens.
: :NONAME
	0 0 CREATE
	HERE @
	DOCOL ,
	] ;

\ Compile LIT
: ['] IMMEDIATE
	' LIT , ;

\ Exception handling with THROW/CATCH...

: EXCEPTION-MARKER
	RDROP
	0 ;

: CATCH ( xt -- exn? )
	DSP@ 4+ >R
	' EXCEPTION-MARKER 4+
	>R
	EXECUTE ;

: THROW ( n -- )
	?DUP IF
		RSP@
		BEGIN
			DUP R0 4- <
		WHILE
			DUP @
			' EXCEPTION-MARKER 4+ = IF
				4+
				RSP!

				DUP DUP DUP

				R>
				4-
				SWAP OVER
				!
				DSP! EXIT
			THEN
			4+
		REPEAT

		\ No catch for this exception, so print a message and restart the
		\ Interpreter.
		DROP
		CASE 
			0 1- OF
				." ABORTED" CR
				ENDOF
			." UNCAUGHT THROW "
			DUP #. CR
		ENDCASE
		QUIT
	THEN ;

: ABORT ( -- )
	0 1- THROW ;

\ Print a stack trace by walking up the return stack
: PRINT-STACK-TRACE
	RSP@
	BEGIN
		DUP R0 4- <
	WHILE
		DUP @
		CASE
			' EXCEPTION-MARKER 4+ OF
				." CATCH ( DSP="
				4+ DUP @ U#.
				." ) "
				ENDOF
			DUP
			CFA>
			?DUP IF
				2DUP
				ID.
				[ CHAR + ] LITERAL EMIT
				SWAP >DFA 4+ - #.
			THEN
		ENDCASE
		4+
	REPEAT
	DROP
	CR ;
: .OK ."  ok." CR ;

\ Finally, print the FemtoForth startup prompt
: .HELLO
	." FemtoForth version " VERSION #. '.' EMIT CR
	.OK ; 
.HELLO
HIDE .HELLO
