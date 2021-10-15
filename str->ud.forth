
// Check if c is a valid digit for current base
// invalid: return -1
// valid: return digit value for base
: valid-digit? ( c -- d )
	// To upper case
	dup 'a' > if 32 - then

	// Check above char Z
	dup 'Z' > if drop -1 exit then

	// Check below char 0
	dup '0' < if drop -1 exit then

	// Check between char 9 and char A
	dup '9' > over 'A' < and if drop -1 exit then

	dup 'A' >= if
		'A' - 16 +
	else
		'0' - 10 +
	then

	dup base >= if
		drop -1 exit
	then

	;

// Convert string to unsigned double
// ( addr len -- result remaining-chars )
: str->u
	0 -rot
	// ( 0 addr remaining-chars )
	begin
		dup 0<> // while there are remaining chars...
	while
		// Get char 
		over c@

		// Validate as digit ( result addr remaining-chars c )
		valid-digit?
		dup 0 < if
			drop nip // ( result remaining-chars )
			exit
		then

		2swap    // ( remaining-chars c result addr )
		-rot     // ( remaining-chars addr c result )
		base * + // ( remaining-chars addr result )
		-rot     // ( result remaining-chars addr )

		// Next
		1+ swap 1- // ( result addr remaining-chars )
	again
	nip // nip the addr
	;
	
