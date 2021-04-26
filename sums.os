: allot ( n -- a ) here tuck + h ! ;
: array ( n -- array ) dup 1+ cells allot tuck ! ;
: len ( array -- n ) @ ;
: idx ( array n -- a ) 1+ cells + ;
: 0..n ( n1 n2 -- f ) \ where f = n1 is between 0 and n2
	over > swap 0>= and ;
: idx? ( array n -- f ) swap len 0..n ;
: idx! ( array i x -- ) -rot idx ! ;
: climit ( a1 u -- a2 a1 ) over + swap ;
: limit ( a1 u -- a2 a1 ) cells over + swap ;
: each ( array xt -- )
	>R
	0 begin
		2dup idx?
	while
		2dup idx @ ( array i x )
		R> dup >R ( array i x xt )
		execute
		1+
	repeat
	R> drop drop drop ;
: cfill ( a u c -- )
	-rot climit ( c a2 a1 )
	begin
		2dup >
	while
		rot ( a2 a1 c )
		2dup swap c!
		-rot
		1+
	repeat ;
: fill ( a u x -- )
	-rot limit ( x a2 a1 )
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
: double dup + ;
: sieve ( array n -- )
	dup double
	begin
		rot swap 2dup idx?
	while ( n array i )
		2dup 0 idx!
		swap -rot
		over +
	repeat
	drop drop drop ;
: ?dup ( a -- a a | 0 ) dup if dup then ;
: prime-sum ( u1 -- u2 ) \ where u2 = sum of primes below u1
	0 >R
	iota 2 ( array i=2 )
	begin
		2dup idx?
	while
		2dup idx @ ( array i x )
		?dup if
			R> + >R
			2dup sieve
		then
		1+
	repeat 
	drop h ! \ free the iota array
	R> ;

