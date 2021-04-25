: \ immediate
	refill drop ;

: char: \ ( -- c )
	['] ?separator word
	ccount drop c@ ;
: find:
	['] ?separator word
	ccount find ;
: ' find: >xt ;

: backref, here - , ;

: begin immediate here ;
: again immediate ['] branch , backref, ;
: until immediate ['] 0branch , backref, ;

: prep-forward-ref \ ( -- a )
	here 0 , ;
: resolve-forward-ref \ ( a -- )
	here over - swap ! ;

: if immediate
	['] 0branch , prep-forward-ref ;
: else immediate
	['] branch , prep-forward-ref
	swap resolve-forward-ref ;
: then immediate
	resolve-forward-ref ;

: unloop
	R> R> R> 2drop >R ;
: do immediate
	['] swap ,
	['] >R ,
	['] >R ,
	0 \ ( do )
	here  \ ( back reference )
	;
: ?do immediate
	['] 2dup ,
	['] swap ,
	['] >R ,
	['] >R ,
	['] <> ,
	['] 0branch , prep-forward-ref
	1 \ ( ?do )
	here \ ( backref )
	;

: bounds \ ( start len -- limit start )
	over + swap ;

: postpone: immediate \ force compile semantics for the next word
	' , ;

: hex 16 base ! ;
: decimal 10 base ! ;
: bin 2 base ! ;

: depth \ ( -- n )
	S0 SP@ -
	4 /
	2 - ; \ would be "1-" but the TOS is in a register...

: rdepth \ ( -- n )
	R0 RP@ -
	4 /
	1- ;

\ Structs
: struct 0 ;
: field:
	create:
	over , +
	does> @ + ;

: cells \ ( x1 -- x2 )
	cell * ;
: allot \ ( u -- a )
	here + h ! ;

\ Output
: line CR emit ;
: u. \ ( u -- )
	u>str type space ;
: . \ ( n -- )
	n>str type space ;
: ? \ ( a -- )
	@ . ;
: id. \ ( link -- )
	>name ccount flenmask and type space ;
: words
	latest @
	begin
		dup ?hidden
		not if
			dup id.
		then
		@
	dup 0=
	until
	drop ;

: recurse immediate
	latest @ >xt , ;

\ Combinators
: dip \ ( a xt -- a )
	swap >R execute R> ;
: keep \ ( a xt -- xt.a a )
	over >R execute R> ;
: bi \ ( a xt1 xt2 -- xt1.a xt2.a )
	['] keep dip execute ;
: bi* \ ( a b xt1 xt2 -- xt1.a xt2.b )
	['] dip dip execute ;
: bi@ \ ( a b xt -- xt.a xt.b )
	dup bi* ;

: getc \ ( -- c )
	begin
		source \ ( a u )
		if
			dup 1+ source!
			c@
			exit
		else
			refill
			2drop
		then
	again ;

: ?interpret \ ( -- f )
	state @ 0= ;

: '"' [ char: " ] literal ;
: ." immediate
	getc drop \ trailing space
	?interpret if
		begin
			getc
			dup '"' = if
				drop exit
			then
			emit
		again
	else
		['] [cstr] , here 0 c,
		here
		begin
			getc
			dup '"' = if
				drop true
			else
				c, false
			then
		until
		here swap - \ write back the string length
		swap c!
		here align h !
		['] type ,
	then ;

." Hello, interpreted!" line

: hi ." Hello, compiled!" line ; hi

bye

