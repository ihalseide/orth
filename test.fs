42 emit \ literal number emit 
42 43 drop emit \ drop 
42 43 swap emit drop \ swap 
42 dup emit \ dup
emit
42 dup drop emit \ drop
1 41 + emit \ addition
1 1 40 + + emit \ addition
43 1 - emit \ subtract
21 2 * emit \ multiply
84 2 /mod emit drop \ divide
85 42 /mod drop emit \ modulo
char * emit \ char 
: Star 42 ;   Star emit \ : (colon)
Star variable Star2   Star2 @ emit \ variable
Star constant Star3   Star3 emit \ constant
36 Base ! 16 emit decimal \ Base, !, decimal
hex 2A emit decimal \ hex, decimal
: star 42 emit ; star \ :
: e emit ; 42 e \ : 
TRUE if star then
-1 if star then
0 if 45 emit else star then
FALSE if 45 emit else star then
23 constant #stars
#stars 17 + emit

\ Compiled begin ... until
( -- ) ( testing parenthetical comments )
: 20star
	#stars
	begin
		star
	dup 1- 0=
	until ;

20star

\ Immediate begin ... until
#stars
begin
	star
dup 1- 0=
until

\ Immediate string printing
." The 3 rows of stars should align!" cr 
." Goodbye, world!" cr

quit
