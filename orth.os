: \ immediate
	refill drop ;

2021 04 25 \ build date: yyyy mm dd
constant: build-day
constant: build-month
constant: build-year

: >= < not ;
: <= > not ;
: 0> 0 > ;
: 0>= 0 >= ;
: 0<= 0 <= ;

: char: \ ( -- c )
	['] ?separator word 1+ c@ ;
: find:
	['] ?separator word
	ccount find ;
: ' find: >xt ;
: hide: find: hide ;

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

: while immediate
	['] 0branch , prep-forward-ref ;
: repeat immediate
	swap ['] branch ,
	backref, resolve-forward-ref ;

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
: times \ ( xt n -- i*x )
	dup 0= if 2drop exit then
	begin
		>R dup >R
		execute
		R> R> 1-
		dup
	0= until
	drop ;

: getc \ ( -- c )
	begin
		source
		if \ ( a )
			dup 1+ source!
			c@
			exit
		else
			refill \ ( a f )
			2drop
		then
	again ;

: ?interpret \ ( -- f )
	state @ 0= ;

: ')' [ char: ) ] literal ;
: ( immediate
	begin
		getc
		')' = if exit then
	again ;
hide: ')'

: '"' [ char: " ] literal ;
: ." immediate
	getc drop \ trailing space
	?interpret if
		begin
			getc dup
		'"' <> while
			emit
		repeat
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
hide: '"'

: bool? dup true = swap false = or ;
: bool. if ." true" else ." false" then ;

: '-' [ char: - ] literal emit ;
: '0' [ char: 0 ] literal emit ;
: . ( u -- ) u>str type ; \ -trailing
: 2. ( u -- ) dup 10 < if '0' then . ;
: build. build-year . '-' build-month 2. '-' build-day 2. ;
: version. ." orth" space build. ;
hide: .
hide: 2.
hide: '-'
hide: '0'

