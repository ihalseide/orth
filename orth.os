( Orth written in itself )

: \ immediate refill drop ;

: backref, here - , ;

: begin immediate here ;
: again immediate ['] branch , backref, ;
: until immediate ['] 0branch , backref, ;

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

: ? ( a -- ) @ . ;

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

: line cr emit ;

: a 42 emit ;
: b a a a a a ;
: c b a b a b ;
c
' a >link hide
' b >link hide
' c >link hide

