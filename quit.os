\ The high-level source for the word "quit"
: quit ( i*x R: j*x -- i*x R: )
	R0 RP!
	postpone: [
	begin
		['] sep? word
		count 2dup
		find dup
		( a u a u link|0 ) 
		if \ found
			nip nip
			>xt execute
		else \ try to convert to number
			drop 2dup ( a u a u )
			str>d ( a u d e|0 )
			0= if
				d>n nip nip
			else \ not a number
				2drop ( a u d -- a u )
				eundef @ execute
			then
		then
	again ;
