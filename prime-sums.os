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

