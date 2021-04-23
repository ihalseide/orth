: \ immediate refill drop ;

: char: \ ( -- c )
	['] ?separator word
	ccount drop c@ ;

char: * emit
bye

: backref, here - , ;

: begin immediate here ;
: again immediate ['] branch , backref, ;
: until immediate ['] 0branch , backref, ;

: prep-forward-ref ( -- a )
	here 0 , ;
: resolve-forward-ref ( a -- )
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
	0 ( do )
	here ( back reference ) ;
: ?do immediate
	['] 2dup ,
	['] swap ,
	['] >r ,
	['] >r ,
	['] <> ,
	['] 0branch , prep-forward-ref
	1 ( ?do )
	here ( backref ) ;

: bounds ( start len -- limit start )
	over + swap ;

: postpone: immediate \ force compile semantics for the next word
	' , ;

: hex 16 base ! ;
: decimal 10 base ! ;
: bin 2 base ! ;

: depth ( -- n )
	S0 SP@ -
	4 /
	2 - ; \ would be "1-" but the TOS is in a register...

: rdepth ( -- n )
	R0 RP@ -
	4 /
	1- ;

\ Structs
: struct 0 ;
: field:
	create:
	over , +
	does> @ + ;

: cells ( x1 -- x2 ) cell * ;
: allot ( u -- a ) here + h store ;

\ Output
: line cr emit ;
: u. ( u -- )
	u>str type space ;
: . ( n -- )
	n>str type space ;
: ? ( a -- ) @ . ;
: id. ( link -- )
	>name ccount flenmask and type space ;
: words ( -- )
	latest @
	begin
		dup ?hidden
		not if
			dup id.
		then
	dup 0=
	until
	drop ;

: recurse immediate ( -- )
	latest @ >xt , ;

\ Combinators
: dip ( a xt -- a )
	swap >R execute R> ;
: keep ( a xt -- xt.a a )
	over >R execute R> ;
: bi ( a xt1 xt2 -- xt1.a xt2.a )
	['] keep dip execute ;
: bi* ( a b xt1 xt2 -- xt1.a xt2.b )
	['] dip dip execute ;
: bi@ ( a b xt -- xt.a xt.b )
	dup bi* ;
