\ This is the rest of my forth written in itself

\ Comparison and Boolean values
: TRUE 1 ;
: FALSE 0 ;
: 0= 0 = ;
: not 0= ;
: <> = not ;
: <= > not ;
: >= < not ; 
: 0> 0 > ;
: 0< 0 < ;
: 0<= 0 <= ;
: 0>= 0 >= ;
: 0<> 0= not ;

\ Incrementation shortcuts
: 1+ 1 + ;
: 1- 1 - ;
: 4+ 4 + ;
: 4- 4 - ; 

\ Negate a number
: negate 0 swap - ;

\ Use the DIVMOD operation defined in assembly
\ in order to create division and mod
: / /mod swap drop ; 
: mod /mod drop ;

\ Whitespace character constants
: BL 32 ;
: '\n' 10 ; 
: '\t' 9 ;

\ Character emitters
: space BL emit ;
: CR '\n' emit ;
: tab '\t' emit ;

\ literal takes whatever is on the stack and compiles it to <lit _x_>
: literal immediate ' lit , , ; 

\ Use literal to define character constants devised at compile-time
: '(' [ char ( ] literal ;
: ')' [ char ) ] literal ;
: ':' [ char : ] literal ;
: ';' [ char ; ] literal ;
: '.' [ char . ] literal ;
: '"' [ char " ] literal ;
: '-' [ char - ] literal ;
: '0' [ char 0 ] literal ;
: 'A' [ char A ] literal ;

\ When in compile mode, [compile] is used to compile the next word even if it is
\ an immediate word.
: [compile] word find >CFA , ;
immediate

: recurse Latest @ >CFA , ;
immediate

\ Define the if/then/else construct
\ unless functions as the inverse of if
: if immediate
	' 0branch , Here @ 0 , ; 
: unless immediate
	' not , [compile] if ;
: then immediate
	dup Here @ swap - swap ! ;  
: else immediate
	' branch ,
	Here @
	0 ,
	swap dup
	Here @ swap -
	swap ! ;

\ Define the begin <code> <condition> UNTIL construct
: begin immediate
	Here @ ; 
: UNTIL immediate
	' 0branch , Here @ - , ;

\ begin <code> again construct
: again immediate
	' branch ,
	Here @ - , ;

\ begin <condition> while <loop code> repeat
\ Compiles to: <condition> 0branch <offset2> <loop code> branch <offset>
: while immediate
	' 0branch ,
	Here @
	0 , ;
: repeat immediate
	' branch ,
	swap
	Here @ - ,
	dup
	Here @ swap -
	swap ! ;

\ Allow ( ... ) as comments within function definitions
: ( immediate
	1 \ Push depth, starting as 1
	begin
		KEY dup \ Get a character
		'(' = if \ Open paren --> increase depth
			drop 1+
		else
			')' = if \ Close paren --> decrease depth
				1-
			then
		then
	dup 0= UNTIL \ Repeat until depth is 0
	drop ; \ drop depth counter

\ ( ... ) comments are now available

\ Words with more complex stack effects
: 2drop ( x x -- ) drop drop ; 
: 2dup ( x1 x2 -- x1 x2 x1 x2 ) over over ; 
: nip ( x y -- y ) swap drop ; 
: TUCK ( x y -- y x y ) swap over ; 
: pick ( x_u ... x_1 x_0 u -- x_u ... x_1 x_0 x_u )
	1+ 4 *
	DSP@ + @ ; 

\ space will print out n spaces. If n < 0, then no spaces are printed.
: space ( n -- )
	begin
		dup 0> \ While n > 0
	while
		SPACE 1- \ Print a space, and decrement
	repeat
	drop ;
	
\ Words for manipulating the number Base
: hex ( -- )
	16 Base ! ;
: decimal ( -- )
	10 Base ! ;
: binary ( -- )
	2 Base ! ;
	
\ Print an unsigned number
: U. ( u -- )
	Base @ /MOD
	?dup if
		recurse
	then
	dup 10 < if
		'0'
	else
		10 - 'A'
	then
	+ emit ;

\ Print out the stack, useful for debugging!
: .s ( -- )
	DSP@
	begin
		dup S0 @ <
	while
		dup @ U.
		SPACE
		4+
	repeat
	drop ;

\ uwidth returns the character width of an unsigned number in the current base
: uwidth
	Base @ /
	?dup if
		recurse 1+
	else
		1
	then ;

\ U.R prints an unsigned number padded to a certain character width
: U.R ( u width -- )
	swap dup
	uwidth
	rot swap -
	space \ space will only print if n is positive
	U. ;

\ .R prints a signed number padded to a certain width
: .R ( n width -- )
	swap ( width n )
	dup 0< if
		NEGATE ( width u )
		\ Save a flag to remember the number was negative
		1 swap rot ( 1 u width )
		- ( 1 u width-1 )

	else
		0 swap rot ( 0 u width )
	then
	swap dup ( flag width u u )
	uwidth ( flag width u uwidth )
	rot swap - ( flag u width-uwidth )
	space ( flag u )
	swap ( u flag )
	if '-' emit then \ if it was negative, print the '-' sign
	U. ;

\ Define . to print out a number with a trailing space
: .
	0 .R
	SPACE ;

\ Redefine U. to really print an unsigned number
: U.
	U. SPACE ;

\ `?' will fetch the number at an address and print it
: ? ( addr -- )
	@ . ;

\ within 
: within ( c a b -- f) \ where f is a<=c<b
	-rot
	over
	<= if
		> if TRUE
		else FALSE
		then
	else
		2drop
		FALSE
	then ;

\ DEPTH returns the stack depth
: DEPTH ( -- n )
	S0 @ DSP@ -
	4- ;

\ Takes an address and rounds it up to the next 4-byte boundary
\ {addr+3 & ~3}
: ALIGNED ( addr -- addr )
	3 +
	3 ~ & ;

\ ALIGN aligns the address of the Here pointer
: ALIGN
	Here @ ALIGNED Here ! ;

\ +! adds a value to the value in an address
: +! ( x addr -- )
	dup ( x addr addr )
	@ ( x addr v )
	rot + ( addr x+v )
	swap ( x+v addr )
	! ;

\ `C,' appends a byte to Here
: C,
	Here @ C!
	1 Here +! ;

\ S" <string> " is used to define strings.
\ This word has to do different things depending on whether it is in compile or
\ in immediate mode.
\ In compile mode, we append the following to the current word:
\	litSTRING <len> <string, rounded to 4-byte>
\ In immediate mode, the string is put at Here, without modifying Here.
: S" immediate ( -- addr len )
	STATE @ if \ Compile mode
		' litSTRING ,
		Here @
		0 ,
		begin
			KEY
			dup '"' <>
		while
			C,
		repeat
		drop
		dup
		Here @ swap -
		4-
		swap !
		ALIGN
	else \ Immediate mode
		Here @
		begin
			KEY
			dup '"' <>
		while
			over C!
			1+
		repeat
		drop
		Here @ -
		Here @
		swap
	then ;

\ ." is the print-string operator
: ." immediate ( -- )
	STATE @ if \ Compile mode
		[compile] S"
		' TELL ,
	else \ Immediate mode
		begin
			KEY
			dup '"' = if
				drop exit
			then
			emit
		again
	then ;

\ SKIPLINK is used to skip link pointers in word headers
: SKIPLINK 4+ ;

\ ID. takes a word dictionary address and prints the word's name
: ID. ( addr -- )
	SKIPLINK
	dup C@ \ get flags and length byte
	F_LENMASK & \ get just the length
	begin
		dup 0>
	while \ while length > 0
		swap 1+
		dup C@
		emit
		swap 1-
	repeat
	2drop ;

\ ?hidden is used to return whether a word is hidden
\ Example: word <word> find ?hidden
: ?hidden ( addr -- flag )
	SKIPLINK
	C@ F_hidden & ;

\ ?immediate does what ?hidden does, but for whether a word is marked immediate
: ?immediate ( addr -- flag )
	SKIPLINK
	C@
	F_IMMED & ;

\ wordS prints out all defined words, except for hidden ones
: wordS ( -- )
	Latest @
	begin
		?dup
	while
		dup ?hidden not if
			dup ID.
			SPACE
		then
		@
	repeat
	CR ;

\ FORGET will deallocate memory by setting Here to point to the word before the
\ given one.
\ Example: FORGET word will move Here to be before word
: forget ( -- )
	word find
	dup @
	Latest !
	Here ! ;

\ dump will print out the contents of memory as a hexdump
: dump ( addr len -- )
	Base @ -rot
	hex
	begin
		?dup
	while
		over 8 U.R
		SPACE

		\ Print up to 16 words per line
		2dup
		1- 15 & 1+
		begin
			?dup
		while
			swap
			dup C@
			2 .R SPACE
			1+ swap 1-
		repeat
		drop

		2dup 1- 15 & 1+
		begin
			?dup
		while
			swap
			dup C@
			dup 32 128 within if
				emit
			else
				drop '.' emit
			then
			1+ swap 1-
		repeat
		drop
		CR

		dup 1- 15 & 1+
		TUCK
		-
		>R + R>
	repeat
	drop
	Base ! ; \ Restore the saved base

\ Now for a non-trivial construct: case/endcase
\ Example:
\	(with something on the stack to compare)
\	case
\	test1 of ... endof
\	test2 of ... endof
\	testn of ... endof
\	... (default)
\	endcase
: case immediate
	0 ;
: of immediate
	' over ,
	' = ,
	[compile] if
	' drop , ;
: endof immediate
	[compile] else ;
: endcase immediate
	' drop ,
	begin
		?dup
	while
		[compile] then
	repeat ;

\ Begin code for a FemtoForth decompiler...

\ CFA> is the opposite of >CFA. It takes a codeword inside the definition of
\ a word and tries to find the matching dictionary definition.
\ It returns 0 if it doesn't find a match.
: CFA>
	Latest @
	begin
		?dup
	while
		2dup swap
		< if
			\ Found, so leave current dictionary entry on the stack
			nip
			exit
		then
		@
	repeat
	\ Nothing found
	drop
	0 ;

\ see decompiles a Word
: see
	word find
	dup if
		\ Decompile if the word was found
		Here @
		Latest @
		begin
			2 pick
			over
			<>
		while
			nip
			dup @
		repeat
		drop swap

		\ Start printing out the source
		':' emit SPACE dup ID. SPACE
		dup ?immediate if ." immediate " then

		>DFA

		begin
			2dup >
		while
			dup @
			case
				' lit of
					4 + dup @
					.
					endof
				' litSTRING of
					[ char S ] literal emit '"' emit SPACE
					4 + dup @
					swap 4 + swap
					2dup TELL
					'"' emit SPACE
					+ ALIGNED
					4 -
					endof
				' 0branch of
					." 0branch ( "
					4 + dup @ .
					." ) "
					endof
				' branch of
					." branch ( "
					4 + dup @ .
					." ) "
					endof
				' ' of
					[ char ' ] literal emit SPACE
					4 + dup @
					CFA>
					ID. SPACE
					endof
				' exit of
					2dup
					4 +
					<> if
						." exit "
					then
					endof
				dup
				CFA>
				ID. SPACE
			endcase
			4 +
		repeat
		';' emit CR
		2drop 
	else
		\ The word was not found
		." undefined. "
	then ;

\ :NONAME creates anonymous words. Execution tokens.
: :NONAME
	0 0 CREATE
	Here @
	DOCOL ,
	] ;

\ Compile lit
: ['] immediate
	' lit , ;

\ Exception handling with throw/catch...

: exception-marker
	Rdrop
	0 ;

: catch ( xt -- exn? )
	DSP@ 4+ >R
	' exception-marker 4+
	>R
	EXECUTE ;

: throw ( n -- )
	?dup if
		RSP@
		begin
			dup R0 4- <
		while
			dup @
			' exception-marker 4+ = if
				4+
				RSP!

				dup dup dup

				R>
				4-
				swap over
				!
				DSP! exit
			then
			4+
		repeat

		\ No catch for this exception, so print a message and restart the
		\ Interpreter.
		drop
		case 
			0 1- of
				." ABORTED" CR
				endof
			." UNCAUGHT throw "
			dup . CR
		endcase
		QUIT
	then ;

: abort ( -- )
	0 1- throw ;

\ Print a stack trace by walking up the return stack
: print-stack-trace
	RSP@
	begin
		dup R0 4- <
	while
		dup @
		case
			' exception-marker 4+ of
				." catch ( DSP="
				4+ dup @ U.
				." ) "
				endof
			dup
			CFA>
			?dup if
				2dup
				ID.
				[ char + ] literal emit
				swap >DFA 4+ - .
			then
		endcase
		4+
	repeat
	drop
	CR ;

\ Begin System interaction and System calls...

\ Multiply a number by 4 because that is how many bytes are in a Forth cell
: CELLS ( n -- n ) 4 * ;

\ Create standard shortcuts for System Calls with a certain number of arguments
: syscall0 0 SYSCALL ;
: syscall1 1 SYSCALL ;
: syscall2 2 SYSCALL ;
: syscall3 3 SYSCALL ;

\ Also, redefine syscall to do nothing now so that making syscalls with too many 
\ parameters isn't easy.
\ (Only syscalls with 0-3 parameters are allowed, at least on ARM chips)
: syscall ;

\ Halt and exit the whole FemtoForth program 
: halt
	0 SYS_exit syscall1 ;

\ Get the program memory breakpoint by calling "brk(0)"
: get-brk ( -- brkpoint )
	0 SYS_brk syscall1 ;
	
\ Get the number of unused memory cells
: unused ( -- n )
	get-brk
	Here @
	-
	4 / ;

: brk ( brkpoint -- )
	SYS_BRK syscall1 ;

: morecore ( cells -- )
	CELLS get-brk + brk ;

\ Redefine hide to not cause a segfault when the word cannot be found
: hide 
	word find dup if
		hidden
	then ; 

\ bye will print out a message and get out of Forth
: bye
	."  bye. "
	halt ;

\ Print out the ok prompt
: ok ."  ok." ;

\ Finally, print the FemtoForth startup prompt
: hello
	." FemtoForth version " VERSION . CR
	unused . ." memory cells remaining" CR
	ok CR ; 
hello
hide hello
