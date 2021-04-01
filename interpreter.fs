: find-word? ( -- ca 0 | xt -1 | xt 1 ) ;

: cs>number ( ca1 -- ud ca2 len ) 0 0 rot >number ;

: do-compile ( -- / x*i -- x*j )
	find-word?  dup if
		1 = if
				execute
		else
				,
		then
	else
		drop cs>number if
		last @ dup @ last ! dp ! abort
	then
		drop drop ['] lit , ,
	then ;

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

