: parse-string-lit ( a2 u1 -- a2 u2 f )
	( get the opening quotation mark )
	over c@ quote <> if
		." first is not quote"
		1 exit
	then
	swap 1+ swap 1-
	2dup ( a1+1 u1-1 a u )
	( traverse the stream until a quotation mark or no more characters left )
	begin
		2dup swap c@ quote <> swap 0 <> and
	while
		swap 1+ swap 1-
	repeat
	( failure if the last char is not a quotation mark )
	over c@ quote <> if
		." last is not quote"
		2drop
		1 exit
	then
	( calculate the string between the quotation marks )
	drop nip ( -- a1+1 a )
	over - ( a2 u2 )
	0 exit ;
