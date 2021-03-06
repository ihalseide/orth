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
: while* ( i*x xt1 xt2 -- j*x xt1 xt2 )
	begin
		dup execute
	while
		>R
		dup >R execute R>
		R>
	repeat ;
\ Anonymous words
: :noname ( -- xt )
	link
	0 , #name here + h !
	entercolon ,
	latest @ hide   // hide the word
	] ;
\ Inline anonymous words, lambda-ish
: { [ immediate ]
	['], here 3 cells + ,
	['] branch , prep-forward-ref
	entercolon , ;
: } [ immediate ]
	['] exit ,
	resolve-forward-ref ;
\ Known times looping combinator
: times ( i*x xt n -- j*x )
	begin
		dup
	0> while
		>R ( i*x xt R: n )
		dup >R execute R>
		R> 1- ( i*x xt n-1 )
	repeat
	drop drop ;
\ case...endcase
: case [ immediate ] ( -- branch-counter ) 0 ;
: of [ immediate ]
	['] over , ['] = ,
	['] 0branch , prep-forward-ref
	['] drop , ;
: endof [ immediate ]
	swap 1+ swap
	['] branch , prep-forward-ref
	swap resolve-forward-ref
	swap ;
: endcase [ immediate ] ( i*a #branches )
	['] res-forward-ref swap times ;

: line CR emit ;
: type ;
: id. ( link -- ) name ccount flenmask and type ;
: >R> ( -- x R: x -- x ) R> dup >R ;
: Rdrop ( R: x -- ) R> drop ;
: NOT ( x -- f ) 0= ;
: bool? ( x -- f ) dup true = swap false = or ;
: bool. ( f -- ) if ." true" else ." false" then space ;
: depth ( -- n )
	S0 SP@ - 4 /
	1- ; \ the TOS is cached in a register
: rdepth ( -- n )
	R0 RP@ -
	4 /
	1- ;

\ Compilation and execution
: find: ( "<word>" -- link-a )
	['] separator? word
	ccount find ;
: ' ( "<name>" -- xt )
	find: >xt ;
: postpone: [ immediate ] \ force compilation of the next word
	' , ;
: ['], ['] ['] , ;

\ Fixed-size (cell) arrays and "iotas"
: array ( n -- array ) dup 1+ cells allot tuck ! ;
: buf ( array -- a ) 1+ ;
: len ( array -- n ) @ ;
: idx ( array n -- a ) buf cells + ;
: 0..n ( n1 n2 -- f ) \ where f = true iff n1 is between 0 and n2
	over > swap 0>= and ;
: idx? ( array n -- f ) swap len 0..n ;
: idx! ( array i x -- ) -rot idx ! ;
: move1 ( a1 a2 -- a3 a4 ) \ copy cell from a1 to a2, increment after
	over @ over !
	swap 1+ swap 1+ ;
: move ( a1 a2 u -- )
	['] move1 swap times 2drop ;
: array-copy ( array1 -- array2 ) \ newly allocated array
	dup len array move ; 
: each ( array xt -- ) \ execute xt on each element of array
	>R
	0 begin
		2dup idx?
	while
		2dup idx @ ( array i x )
		>R> ( array i x xt )
		execute
		1+
	repeat
	R> drop drop drop ;
: limit ( a1 u -- a2 a1 ) over + swap ;
: fill ( a u x -- )
	-rot cells limit ( x a2 a1 )
	begin
		2dup >
	while
		rot ( a2 a1 x )
		2dup swap !
		-rot
		cell +
	repeat ;
: iota ( n -- array )
	dup array
	swap 1- ( array n-1 )
	begin dup 0>= while
		2dup idx
		over swap !
		1-
	repeat
	drop ;
\ Cons cells, pairs
: cons ( x1 x2 -- cons )
	2 cells allot
	tuck cell + ! ! ;
: car ( cons -- x ) @ ;
: cdr ( cons -- x ) cell + @ ;

\ Etc.
: u. ( u -- ) u>str type space ;
: . ( n -- ) n>str type space ;
: ? ( a -- ) @ . ;

\ Inspection
: next-link ( link1 -- link2 )
	dup latest @ = if \ special case for latest word
		drop here exit
	then
	latest @
	begin
		2dup @ <>
	while
		@
	repeat 
	nip ;

: words.
	latest @
	begin
		dup
	while
		dup hidden?
		not if
			dup id. space
		then
		@
	repeat
	drop ;

: sep? ( c -- f ) \ whitespace predicate
    dup 0 = swap  ( f c )
	dup 9 = swap  ( f f c )
	dup 10 = swap ( f f f c )
	dup 13 = swap ( f f f c )
	BL =          ( f f f f )
	or or or or ; ( f ) 
