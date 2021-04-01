: ! <store> ;
: & <and> ;
: (;code) <do_semi_code> ;
: * <multiply> ;
: + <add> ;
: , <comma> ;
: - <sub> ;
: / <divide> ;
: /mod <divmod> ;
: 0branch <zero_branch> ;
: < <lt> ;
: = <equal> ;
: > <gt> ;
: >CFA <to_cfa> ;
: >R <to_r> ;
: >number <to_number> ;
: @ <fetch> ;
: R> <r_from> ;
: ^ <xor> ;
: accept <accept> ;
: branch <branch> ;
: bye <bye> ;
: c! <cstore> ;
: c@ <cfetch> ;
: count <count> ;
: drop <drop> ;
: dup <dup> ;
: emit <emit> ;
: execute <exec> ;
: exit <exit> ;
: find <find> ;
: invert <invert> ;
: lit <lit> ;
: mod <mod> ;
: negate <negate> ;
: nip <nip> ;
: no_rstack <no_rstack> ;
: over <over> ;
: rot <rot> ;
: swap <swap> ;
: tell <tell> ;
: word <word> ;
: | <or> ;

0 variable state
0 variable >in
0 variable #tib
10 variabe base
<tib> variable tib
<dictionary end> variable h
<last word> variable last

: >LFA ( addr -- addr2 )
	4 + ;
	// 
	define >LFA 4  to_lfa docol
	.word xt_lit 4 xt_add
	.word xt_exit

: immediate immediate ( -- )
	last @ >LFA
	dup c@
	F_IMMEDIATE &
	swap c! ;

: : immediate ( -- )
	create [
	<docol> (;code) ;

: :: ( -- )
	postpone :
	postpone immediate ;

: ; immediate
	` exit ,
	] ;

: create
	h @
	last @ ,
	last !
	32 word count +
	h !
	0 ,
	<dovar> (;code) ;

: constant  ( x -- )
	create ,
	<doconst> (;code) ;

: ] ( -- ) \ enter compile mode
	1 state ! ;

: [ immediate ( -- ) \ enter interpret/immediate mode
	0 state ! ;
