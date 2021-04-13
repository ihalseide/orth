: find-word? ( -- ca 0 | xt -1 | xt 1 ) ;

: cs>number ( ca1 -- ud ca2 len ) 0 0 rot >number ;

: do-compile ( -- / x*i -- x*j )
	find-word?  dup
	if
		( #1 ) 1 =
		if
			( #2 ) execute
		else
			( #3 ),
		then
	else
		( #4 ) drop cs>number
		if
			( #5 ) last @ dup @ last ! dp ! abort
		then
		( #6 ) drop drop ['] lit , ,
	then 
	( #7 ) ;

: do-interpret ( --n / x*i -- x*j )
	find-word? dup if
		execute
	else
		drop cs>number if
			abort
		then
		drop drop
	then ;

: interpreter ( -- )
	begin
		source >in @ = if refill then
		drop state @ if
			do-compile
		else
			do-interpret
		then
	again ;

