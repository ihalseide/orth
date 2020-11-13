42 EMIT \ Test EMIT 
42 43 DROP EMIT \ Test DROP 
42 43 SWAP EMIT DROP \ Test SWAP 
42 DUP EMIT EMIT \ Test DUP
42 DUP DROP EMIT 
1 41 + EMIT \ Test addition
1 1 40 + + EMIT 
43 1 - EMIT \ Test subtraction 
21 2 * EMIT \ Test multiplication 
84 2 /MOD EMIT DROP
85 42 /MOD DROP EMIT 
CHAR * EMIT \ Test CHAR 
: star 42 EMIT ; star \ Test : (colon)
: e EMIT ; 42 e \ ditto
\ This program should emit the same number of stars as the line number for the line above this line.
10 EMIT \ End with CR
