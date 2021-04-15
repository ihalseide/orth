( --- low level code --- )

low_level_interpreter: ( -- )
	* get a word
	* try to find it
	* if it's found, execute it
	* otherwise convert it to a number
	* push the number to the stack
	* repeat

find: ( addr u -- xt )
	* search the dictionary for the word

low_level_constant:
	* doconst

low_level_variable:
	* dovar

! ( x addr -- )

@ ( addr -- x )

+ ( x1 x2 -- x3 )

- ( x1 x2 -- x3 )

* ( x1 x2 -- x3 )

/ ( x1 x2 -- x3 )

mod ( x1 x2 -- x3 )

negate ( x1 -- x2 )

not ( x1 -- x2 )

and ( x1 x2 -- x3 )

or ( x1 x2 -- x3 )

xor ( x1 x2 -- x3 )

dup ( x -- x x )

drop ( x -- )

swap ( x1 x2 -- x2 x1 )

nip ( x1 x2 -- x2 )

over ( x1 x2 -- x1 x2 x1 )

variable H ( -- addr )

variable >in ( -- addr )

constant #tib ( -- x ) \ where x is the capacity of the input buffer

constant tib ( -- x ) \ where x is the address of the input buffer

constant enter ( -- x ) \ where x is the code address to execute for enter/docolon

key ( -- c )

emit ( c -- )

exit ( -- )

lit ( -- x )

branch ( -- )

0branch ( x -- )

create "name" ( -- )

' "name" ( -- xt )

( --- high level code --- )

create :
	H @ ( make the new word be the latest word )
	latest !
	' create , ( create the name )
	' lit , ' docol , ( make it run docol )
	' , ,
	' lit , 1 , ( enter compile mode )
	' state , ' ! ,
	' exit ,

create ;
	' lit , ' exit , ( compile exit code )
	' , ,
	' exit ,

\ <?> constant f-hidden

\ <?> constant f-immediate

\ <?> constant f-length

: literal ( x -- )
	' lit ,
	, ;

: >link ( xt -- addr )
	36 - ;

: >xt ( addr -- xt )
	36 + ;

: if ( -- addr )
	here
	0 literal
	' 0branch , ;
immediate

: else ( addr -- addr )
	here
	swap ! ;
immediate

: then ( addr -- )
	here
	swap ! ;
immediate

\ redefine variable to do different things based on the state
\ <compiling> ( -- ) compiles parameter addr 
\ <immediate> ( -- addr )
: (variable)
	state @ if
		>params
		literal		
	else
		>params
	then ;

\ redefine constant to do different things based on the state
\ <compiling> ( -- ) compiles constant value
\ <immediate> ( -- x ) 
: (constant)
	state @ if
		>params @
		literal		
	else
		>params @
	then ;

0 constant false

false not constant true

: here ( -- addr )
	H @ ;

: hide ( addr -- )
	>name
	dup
	@
	f-hidden and
	! ;

: !+ ( x addr -- addr2 )
	swap over
	! 1 + ;

\ local
variable x

: accept ( addr u -- u2)
	dup x ! \ save num of chars accepted
	begin
		swap ( u addr )
		key ( u addr c )
		dup not if
			drop drop
			x @
			swap -
			exit
		then
		swap ( u c addr )
		!+   ( u addr)
		swap ( addr u )
		1 -
	again
	drop drop
	x @ ;

\ make sure that a new "x" could be used later
' x >link hide

: refill ( -- )
	>in @ #tib
	>= if
		tib #tib accept
		not if
			bye
		then
		0 >in !
	then ;

\ skip the character in the input
: skip ( c -- )
	>in tib +
	begin
		over over
		c@ = if
			1 +
		else
			tib swap -
			>in !
			exit
		then
	again ;

\ get the input string until the given character
: word ( c -- addr u )
	>in tib +
	begin
		over over ( c addr c addr )
		c@ = if
			nip ( addr )
			dup
			tib
			swap - 
			dup
			>in !
			exit
		then
		1 +
	again ;

: find ( addr u -- xt | 0 ) ... ;

: next-word ( -- addr u )
	refill
	BL skip
	BL word ;

: cs>num ( addr u -- d u ) ... ;

: undefined. ( addr u -- )
	char " emit                   \ "
	tell
	[ char " ] literal emit       \ "
	[ char ? ] literal emit ;

: forget ( addr -- )
	dup
	H !
	@ latest ! ;

: cancel ( -- )
	latest @
	forget
	0 state ! ;

: interpret ( addr u -- f )
	over over
	find
	dup if
		state @ if
			,
		else
			execute
		then
		drop drop
	else
		drop
		cs>num if
			drop drop
			[ false ] literal
			exit
		then
		nip
		state @ if
			literal
		then
	then
	[ true ] literal ;

: quit ( -- )
	R0 RSP!
	begin
		next-word
		over over
		interpret
		not if
			undefined.
			state @ if
				cancel
			then
		else
			drop drop
		then
	1 again ;

: postpone ( -- )
	next-word
	find , ;

