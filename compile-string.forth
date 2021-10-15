: ,string ( a1 u1 -- )
	dup align dup
	['] branch , , 
	>R
	( a1 u1 ) ( u2 )
	dup >R
	( a1 u1 ) ( u2 u1 )
	here
	( a1 u1 H ) ( u2 u1 )
	cmove
	( ) ( u2 u1 )
	R> R>
	( u1 u2 )
	here dup >R
	( u1 u2 H ) ( H )
	+ h !
	( u1 ) ( H )
	R>
	literal literal ;
