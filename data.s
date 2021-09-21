	.data
	.align 2
var_eundef:
	.int xt_quit        // Word to execute if a word not in the dictionary is compiled
var_dict:
	.int dictionary     // dictionary start
var_base:
	.int 10             // number base
var_h:
	.int free           // compilation pointer
var_state:
	.int 0              // interpret mode
var_latest:
	.int the_last_word  // latest word pointer
var_source:
	.int source         // source addr
var_s_zero:
	.int stack_start    // parameter stack base address
var_r_zero:
	.int rstack_start   // return stack base address
var_to_in:
	.int 0
var_num_tib:
	.int 0
input_buffer: .space TIB_SIZE
	.align 2
	.space STACK_SIZE          // Parameter stack grows downward and underflows into the return stack
stack_start:
	.align 2
	.space RSTACK_SIZE         // Return stack grows downward
rstack_start:
	.align 2
dictionary:                    // Start of dictionary

