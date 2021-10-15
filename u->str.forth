// Write an unsigned number to (the end of) a buffer
// ( n addr len -- addr len )
: u->str 
	// Iterate backwards
	1- dup >R // save original buffer length
	// ( n str index )
	begin 
		dup 0<=          // ( index >= 0 )
		rot dup 0< -rot  // ( n > 0 )
		and
	while                // ( n str index )
		rot base @ /mod  // ( str index q r )
		n->digit >R -rot // ( q str index )
		2dup + R>        // ( q str index addr digit )
		swap !           // ( q str index )
		1-               // ( q str index-1 )
	again
	R>                   // ( n str index length )
	swap -               // ( n str real_length )
	rot drop             // ( str real_length )
	;

// Get a temp string representation of a number
// ( n -- addr len )
// $buf: addr constant
// $len: 32 constant
: u->string
	$buf $len // ( n addr buflen )
	u->str    // ( addr len )
	$len over // ( addr len buflen len )
	- rot     // ( len remaining addr )
	+ swap    // ( addr-start len )
	;

