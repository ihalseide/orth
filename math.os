: square ( n -- u ) dup * ;
: even? ( n -- f ) 2 mod 0= ; 
: odd? ( n -- f ) even? not ; 
