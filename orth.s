	// ( x1 x2 x3 -- x1 x2 x3 x1 x2 x3 )
	defword "3dup", 4, three_dup
	.int xt_dup
	.int xt_two_over
	.int xt_rot
	.int xt_exit

	// ( x -- )
	defword "literal", 7, literal, F_COMPILE+F_IMMEDIATE 
	.int xt_lit, xt_lit, xt_comma
	.int xt_comma
	.int xt_exit

	defword "entercolon", 10, entercolon
	.int xt_lit, enter_colon
	.int xt_exit

	defword "entervariable", 13, entervariable
	.int xt_lit, enter_variable
	.int xt_exit

	defword "enterconstant", 13, enterconstant
	.int xt_lit, enter_constant
	.int xt_exit

	// ( a u1 -- u2 )
	defword "accept", 6, accept
	.int xt_dup, xt_to_r             // ( a u1 R: u1 )
accept_char:
	.int xt_dup, xt_zero_branch
	label accept_done
	.int xt_swap
	.int xt_key                      // ( u a c R: u1 )
	.int xt_dup, xt_lit, 10, xt_equals
	.int xt_not, xt_zero_branch
	label accept_break
	.int xt_over, xt_store           // ( u a R: u1 )
	.int xt_one_plus
	.int xt_swap
	.int xt_one_minus
	.int xt_branch
	label accept_char
accept_break:
	.int xt_drop
accept_done:
	.int xt_drop                     // ( u R: u1 )
	.int xt_r_from
	.int xt_swap, xt_minus
	.int xt_exit

	defword ";", 1, semicolon, F_COMPILE+F_IMMEDIATE
	.int xt_lit, xt_exit, xt_comma      // compile exit code
	.int xt_latest, xt_fetch, xt_hide   // toggle the hide flag to show the word
	.int xt_bracket                     // enter the immediate interpreter
	// no exit

	defword ":", 1, colon
	.int xt_header
	.int xt_entercolon, xt_comma        // make the word run docol
	.int xt_latest, xt_fetch, xt_hide   // hide the word
	.int xt_rbracket                    // enter the compiler
	// no exit

	// ( -- ) create link field
	defword "link", 4, link
	.int xt_here, xt_align, xt_h, xt_store
	.int xt_here                        // here = this new link address
	.int xt_latest, xt_fetch, xt_comma  // link field points to previous word
	.int xt_latest, xt_store            // make this link field address the latest word
	.int xt_exit

	// ( -- ) create link and name field in dictionary
	defword "header:", 7, header
	.int xt_link
	.int xt_lit, xt_sep_q
	.int xt_word                  // ( a )
	.int xt_dup, xt_dup
	.int xt_c_fetch               // ( a a len )
	.int xt_num_name, xt_min
	.int xt_swap, xt_c_store      // ( a )
	.int xt_num_name, xt_one_plus, xt_plus
	.int xt_h, xt_store
	.int xt_exit

	// ( -- )
	defword "align", 5, align
	.int xt_lit, 3, xt_plus
	.int xt_lit, 3, xt_not, xt_and // a2 = (a1+(4-1)) & ~(4-1);
	.int xt_exit

	defword "here", 4, here // current compilation address
	.int xt_h, xt_fetch
	.int xt_exit

	// ( -- ) interpret mode
	defword "[", 1, bracket, F_COMPILE+F_IMMEDIATE
	.int xt_state, xt_fetch
	.int xt_zero_branch
	label already_interpret
	.int xt_false, xt_state, xt_store
	.int xt_quit
already_interpret:
	.int xt_exit

	// ( -- ) compiler
	defword "]", 1, rbracket
	.int xt_true, xt_state, xt_store
compile:
	.int xt_lit, xt_sep_q
	.int xt_word
	.int xt_count                      // ( a u )
	.int xt_two_dup
	.int xt_find, xt_dup
	.int xt_zero_branch            // ( a u link|0 )
	label compile_no_find
	.int xt_nip, xt_nip            // ( link )
	.int xt_dup, xt_question_immediate
	.int xt_zero_branch
	label compile_normal
	.int xt_to_xt
	.int xt_execute      // immediate
	.int xt_branch
	label compile
compile_normal:
	.int xt_to_xt, xt_comma
	.int xt_branch
	label compile
compile_no_find:
	.int xt_drop
	.int xt_two_dup                // ( a u a u )
	.int xt_str_to_d               // ( a u d e|0 )
	.int xt_zero_branch
	label compile_number
	.int xt_two_drop               // ( a u d -- a u )
	.int xt_eundefc, xt_fetch, xt_execute
	.int xt_branch
	label compile
compile_number:
	.int xt_d_to_n
	.int xt_lit, xt_lit, xt_comma // compiles "lit #"
	.int xt_comma
	.int xt_two_drop
	.int xt_branch
	label compile

	// ( xt -- link )
	defword ">link", 5, to_link
	.int xt_lit, 4+1+F_LENMASK, xt_minus
	.int xt_exit

	// ( link -- a )
	defword ">name", 5, to_name
	.int xt_lit, 4, xt_plus
	.int xt_exit

	// ( link -- xt )
	defword ">xt", 3, to_xt
	.int xt_lit, 4+1+F_LENMASK
	.int xt_plus
	.int xt_exit

	// ( link -- a2 )
	defword ">params", 7, to_params
	.int xt_lit, 4+1+F_LENMASK+4, xt_plus
	.int xt_exit

	// ( link -- f )
	defword "hidden?", 7, question_hidden
	.int xt_to_name, xt_c_fetch
	.int xt_fhidden, xt_and, xt_bool
	.int xt_exit

	// ( link -- f )
	defword "immediate?", 10, question_immediate
	.int xt_to_name, xt_c_fetch
	.int xt_fimmediate, xt_and, xt_bool
	.int xt_exit

	// ( link -- f )
	defword "compilation?", 12, compilation_q
	.int xt_to_name, xt_c_fetch
	.int xt_fcompile, xt_and, xt_bool
	.int xt_exit

	// ( a1 -- a2 c )
	defword "count", 5, count
	.int xt_dup               // ( a1 a1 )
	.int xt_one_plus, xt_swap // ( a2 a1 )
	.int xt_c_fetch           // ( a2 c )
	.int xt_exit

	// ( a u1 -- d u2 ), assume u1 > 0
	defword "str>d", 5, str_to_d
	.int xt_over, xt_c_fetch
	.int xt_lit, '-', xt_equals
	.int xt_zero_branch               // ( a u1 )
	label str_to_d_positive
	.int xt_one_minus                 // len--
	.int xt_swap
	.int xt_one_plus                  // addr++
	.int xt_swap
	.int xt_str_to_ud                 // ( ud u2 )
	.int xt_swap, xt_negate, xt_swap  // ( d u2 )
	.int xt_over, xt_zero_equals
	.int xt_zero_branch
	label str_to_d_not_zero
	.int xt_rot, xt_negate, xt_minus_rot
str_to_d_not_zero:
	.int xt_exit
str_to_d_positive:
	.int xt_str_to_ud                 // ( a u1 -- d u2 )
	.int xt_exit

	// ( d -- n )
	defword "d>n", 3, d_to_n
	.int xt_lit, 0, xt_less
	.int xt_zero_branch
	label d_to_n_positive
	.int xt_negate
d_to_n_positive:
	.int xt_exit

	// ( n -- a u )
	defword "n>str", 5, n_to_str
	.int xt_dup                       // ( n n )
	.int xt_lit, 0, xt_less
	.int xt_zero_branch
	label n_positive                  // ( n )
	.int xt_negate                    // ( u )
	.int xt_u_to_str                  // ( a u )
	.int xt_one_plus                  // length+1
	.int xt_swap, xt_one_minus        // ( u a )
	.int xt_lit, '-'                  // ( u a '-' )
	.int xt_over, xt_c_store          // ( u a )
	.int xt_swap                      // ( a u )
	.int xt_exit
n_positive:                           // ( n )
	.int xt_u_to_str                  // ( a u )
	.int xt_exit

	// ( link -- )
	defword "hide", 4, hide
	.int xt_to_name
	.int xt_dup, xt_c_fetch
	.int xt_fhidden, xt_xor
	.int xt_swap, xt_c_store
	.int xt_exit

	defword "CR", 2, cr
	.int xt_lit, '\n'
	.int xt_exit

	defword "BL", 2, bl
	.int xt_lit, 32
	.int xt_exit

	defword "space", 5, space
	.int xt_bl, xt_emit
	.int xt_exit

	// ( x -- f )
	defword "bool", 4, bool                
	.int xt_zero_branch
	label bool_done
	.int xt_true
	.int xt_exit
bool_done:
	.int xt_false
	.int xt_exit

	// ( a1 u1 a2 u2 -- f ) compare counted strings
	defword "compare", 7, compare          
	.int xt_rot, xt_swap               // ( a1 a2 u2 u1 )
	.int xt_two_dup, xt_equals, xt_zero_branch
	label compare_len_neq
	.int xt_drop                       // ( a1 a2 u2 )
compare_next:
	.int xt_dup, xt_zero_branch
	label compare_eql
	.int xt_minus_rot
	.int xt_two_dup
	.int xt_c_fetch, xt_swap
	.int xt_c_fetch, xt_equals
	.int xt_zero_branch
	label compare_neq
	.int xt_one_plus, xt_swap
	.int xt_one_plus, xt_swap
	.int xt_rot
	.int xt_one_minus
	.int xt_branch
	label compare_next
compare_eql:
	.int xt_drop, xt_drop, xt_drop
	.int xt_true
	.int xt_exit
compare_neq:
	.int xt_drop, xt_drop, xt_drop
	.int xt_false
	.int xt_exit
compare_len_neq:
	.int xt_two_drop, xt_two_drop
	.int xt_false
	.int xt_exit

	// ( a u -- link | 0 )
	defword "find", 4, find                
	.int xt_latest, xt_fetch           // ( a u link )
find_link:
	.int xt_dup
	.int xt_zero_branch
	label find_no_find                 // ( a u link )
	.int xt_dup, xt_question_hidden
	.int xt_not, xt_zero_branch
	label find_skip_hidden
	.int xt_dup, xt_two_swap, xt_rot   // ( link a1 len1 link )
	.int xt_to_name, xt_count         // ( link a1 len1 a2 len2 )
	.int xt_flenmask, xt_and
	.int xt_two_over                   // ( link a1 len1 a2 len2 a1 len1 )
	.int xt_compare, xt_not
	.int xt_zero_branch
	label find_found
	.int xt_rot                        // ( a1 len1 link )
find_skip_hidden:
	.int xt_fetch
	.int xt_branch
	label find_link
find_found:
	.int xt_two_drop
	.int xt_exit
find_no_find:
	.int xt_two_drop, xt_drop
	.int xt_false
	.int xt_exit

	defword "0=", 2, zero_equals
	.int xt_lit, 0, xt_equals
	.int xt_exit

	defword "immediate", 9, immediate // makes the most recently defined word immediate (word is not itself immediate)
	.int xt_latest, xt_fetch
	.int xt_to_name, xt_dup
	.int xt_c_fetch, xt_fimmediate, xt_xor
	.int xt_swap, xt_c_store
	.int xt_exit

	defword "compilation", 11, compilation, F_IMMEDIATE
	.int xt_latest, xt_fetch
	.int xt_to_name, xt_dup
	.int xt_c_fetch, xt_fcompile, xt_xor
	.int xt_swap, xt_c_store
	.int xt_exit

	// ( c1 -- a1 ) scan source for word delimited by c1 and copy it to the memory pointed to by `here`
	defword "word", 4, word           // ( c1 -- a1 )
word_input:
	.int xt_source                // ( c1 a u )
	.int xt_dup, xt_zero_equals
	.int xt_zero_branch           // ( c1 a u )
	label word_copy
	.int xt_two_drop              // ( c1 )
	.int xt_refill, xt_drop       // ( c1 )
	.int xt_branch
	label word_input
word_copy:                        // ( c1 a u )
	.int xt_to_r                  // ( c1 a R: u )   >R
	.int xt_over                  // ( c1 a c1 )
	.int xt_skip                  // ( c1 a3 )
	.int xt_swap, xt_two_dup      // ( a3 c1 a3 c1 )
	.int xt_scan                  // ( a3 c1 a4 )
	.int xt_nip                   // ( a3 a4 )
	.int xt_dup, xt_tib, xt_minus // update >in
	.int xt_to_in, xt_store
	.int xt_over, xt_minus        // ( a3 u )
	.int xt_r_from, xt_max        // ( a3 u R: )      R>
	.int xt_dup, xt_to_r          // ( a3 u R: u )   >R
	.int xt_here                  // ( a3 u a1 )
	.int xt_one_plus              // ( a3 u a1+1 )
	.int xt_swap                  // ( a3 a1+1 u )
	.int xt_cmove                 // ( )
	.int xt_r_from                // ( u R: )         R>
	.int xt_here, xt_c_store      // ( )
	.int xt_here                  // ( a1 )
	.int xt_exit

the_last_word:

	// ( i*x R: j*x -- i*x R: )
	defword "quit", 4, quit 
	.int xt_r_zero, xt_rp_store    // clear return stack
	.int xt_break
	.int xt_bracket
quit_interpret:
	.int xt_lit, xt_sep_q, xt_word
	.int xt_count                  // ( a u )
	.int xt_two_dup
	.int xt_find, xt_dup
	.int xt_zero_branch            // ( a u link|0 )
	label quit_no_find
	.int xt_nip, xt_nip
	.int xt_to_xt, xt_execute
	.int xt_branch
	label quit_interpret
quit_no_find:
	.int xt_drop
	.int xt_two_dup                // ( a u a u )
	.int xt_str_to_d               // ( a u d e|0 )
	.int xt_zero_branch
	label quit_number
	.int xt_two_drop               // ( a u d -- a u )
	.int xt_eundef, xt_fetch, xt_execute
	.int xt_branch
	label quit_interpret
quit_number:
	.int xt_d_to_n
	.int xt_nip, xt_nip
	.int xt_branch
	label quit_interpret

free: 

