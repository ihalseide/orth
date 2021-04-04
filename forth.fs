\ Define the begin <code> <condition> UNTIL construct
: begin immediate
	Here @ ; 
: until immediate
	' 0branch , Here @ - , ;

\ "begin ... again" construct
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
	dup 0= until \ Repeat until depth is 0
	drop ; \ drop depth counter

\ print out n spaces
: spaces ( n -- )
	begin
		dup
	0> while
		SPACE
		1-
	repeat
	drop ;
	
\ Print an unsigned number
: U. ( u -- )
	Base @         ( u u )
	/MOD           ( ur uq )
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
		dup
		S0 @
	< while
		dup @
		U.
		SPACE
		4+
	repeat
	drop ;

\ uwidth returns the character width of an unsigned number in the current base
: uwidth ( u1 -- u2 )
	Base @
	/
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
	spaces
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

