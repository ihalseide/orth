/* FemtoForth.c
 * Intended compilation command (C99):
 * `gcc -g -std=c99 -Wall -Werror'
 */

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <string.h>

long * dsp;
long * rsp;
long * var_S0; 
long * var_R0; 

void *xmalloc(size_t num_bytes) {
    void *ptr = malloc(num_bytes);
    if (!ptr) {
        perror("\txmalloc failed\n");
        exit(1);
    }
    return ptr;
} 

bool is_space (char x)
{
	switch (x) {
		case ' ':
		case '\n':
		case '\t':
		case '\v': 
			return true;
		default:
			return false;
	}
}

/* Convert an alphanumeric character into a number value.
 * Use this method because it's more understandable than math on ascii characters.
 * Used for reading numbers in multiple bases.
 * Returns -1 if the character is invalid.
 */
int char_to_value (char c)
{
	switch (c)
	{
		case '0':
			return 0;
		case '1':
			return 1;
		case '2':
			return 2;
		case '3':
			return 3;
		case '4':
			return 4;
		case '5':
			return 5;
		case '6':
			return 6;
		case '7':
			return 7;
		case '8':
			return 8;
		case '9':
			return 9; 
		case 'a': case 'A':
			return 10;
		case 'b': case 'B':
			return 11;
		case 'c': case 'C':
			return 12;
		case 'd': case 'D':
			return 13;
		case 'e': case 'E':
			return 14;
		case 'f': case 'F':
			return 15;
		case 'g': case 'G':
			return 16;
		case 'h': case 'H':
			return 17;
		case 'i': case 'I':
			return 18;
		case 'j': case 'J':
			return 19;
		case 'k': case 'K':
			return 20;
		case 'l': case 'L':
			return 21;
		case 'm': case 'M':
			return 22;
		case 'n': case 'N':
			return 23;
		case 'o': case 'O':
			return 24;
		case 'p': case 'P':
			return 25;
		case 'q': case 'Q':
			return 26;
		case 'r': case 'R':
			return 27;
		case 's': case 'S':
			return 28;
		case 't': case 'T':
			return 29;
		case 'u': case 'U':
			return 30;
		case 'v': case 'V':
			return 31;
		case 'w': case 'W':
			return 32;
		case 'x': case 'X':
			return 33;
		case 'y': case 'Y':
			return 34;
		case 'z': case 'Z':
			return 35;
		default:
			return -1;
	}
}

long bool_to_forth (bool b)
{
	return b? -1l : 0l;
}

long forth_bool (bool b)
{
	return b? -1l : 0l;
}
// Convert a Null-terminated string into a Length-encoded string
void string_copy_null_to_length
(const char * source, size_t length, char * dest)
{
	strncpy(dest + 1, source, length);
	*dest = (char) length;
	assert(((size_t)(*dest)) == length);
} 

void string_copy_null_to_length_test ()
{
	char * s1 = "Hello, world!";
	int l1 = 5;
	char * d1 = xmalloc(sizeof(char) * (1 + l1));
	string_copy_null_to_length(s1, l1, d1);
	assert(d1[0] == l1);
	for (int i = 0; i < l1; i++) {
		assert(d1[1 + i] == s1[i]);
	}
} 

void data_push (long x)
{
	*dsp = x;
	dsp++;
}

long data_pop ()
{
	dsp--;
	return *dsp;
}

long data_top ()
{
	return *(dsp-1);
} 

void returns_push (long x)
{
	*rsp = x;
	rsp++;
}

long returns_pop ()
{
	rsp--;
	return *rsp;
} 

void do_rdrop ()
{
	returns_pop();
}

void do_dup ()
{
	data_push(data_top());
}

void do_swap ()
{
	long a = data_pop();
	long b = data_pop();
	data_push(a);
	data_push(b);
}

void do_drop ()
{
	data_pop();
}

/* rot ( a b c -- c a b ) */
void do_rot ()
{
	long c = data_pop();
	long b = data_pop();
	long a = data_pop();
	data_push(c);
	data_push(a);
	data_push(b);
}

/* -rot ( a b c -- b c a ) */
void do_irot ()
{
	long c = data_pop();
	long b = data_pop();
	long a = data_pop();
	data_push(b);
	data_push(c);
	data_push(a); 
}

void do_over ()
{
	data_push(*(dsp-2));
}

/* >R */
void do_to_r ()
{
	returns_push(data_pop());
}

/* R> */
void do_from_r ()
{
	data_push(returns_pop());
}

void do_S0 ()
{
	data_push((long) var_S0);
}

void do_R0 ()
{
	data_push((long) var_R0);
}

void do_RSP_fetch ()
{
	data_push((long) rsp);
}

void do_DSP_fetch ()
{
	data_push((long) dsp);
}

void do_RSP_store ()
{
	rsp = (long *) data_pop();
}

void do_DSP_store ()
{
	dsp = (long *) data_pop();
}

/* emit ( c -- ) */
void do_emit ()
{
	putchar(data_pop());
}

/* key ( -- c ) */
void do_key ()
{
	data_push(getchar());
}

/* Quick! math operators */
void do_add () { data_push(data_pop() + data_pop()); } 
void do_sub () { data_push(-data_pop() + data_pop()); } 
void do_mul () { data_push(data_pop() * data_pop()); } 
void do_negate () { data_push(-data_pop()); } 
void do_double () { data_push(data_pop() * 2); }
void do_halve () { data_push(data_pop() / 2); }
/* Comparison operators */
void do_equ () { data_push(forth_bool(data_pop() == data_pop())); } 
void do_neq () { data_push(forth_bool(data_pop() != data_pop())); }
void do_lt  () { data_push(forth_bool(data_pop() <  data_pop())); }
void do_gt  () { data_push(forth_bool(data_pop() >  data_pop())); }
void do_le  () { data_push(forth_bool(data_pop() <= data_pop())); }
void do_ge  () { data_push(forth_bool(data_pop() >= data_pop())); }
/* Comparison with zero */
void do_zequ () { data_push(forth_bool(data_pop() == 0));}
void do_zneq () { data_push(forth_bool(data_pop() != 0));}
void do_zlt  () { data_push(forth_bool(data_pop() <  0));}
void do_zgt  () { data_push(forth_bool(data_pop() >  0));}
void do_zle  () { data_push(forth_bool(data_pop() <= 0));}
void do_zge  () { data_push(forth_bool(data_pop() >= 0));}
/* Bitwise operators */
void do_and () { data_push(data_pop() & data_pop());}
void do_or () { data_push(data_pop() | data_pop());}
void do_xor () { data_push(data_pop() ^ data_pop());}
void do_invert () { data_push(~ data_pop()); } 

/* ?DUP ( n -- n n ) | ( 0 -- 0 ) */
void do_qdup ()
{
	if (data_top() != 0)
	{
		data_push(data_top());
	}
}

/* ! ( value addr -- ) store */
void do_store ()
{
	long * addr = (long *) data_pop();
	*addr = data_pop();
}

/* @ ( addr -- value ) fetch */
void do_fetch ()
{
	long * addr = (long *) data_pop();
	data_push(*addr);
}

/* C! ( value addr -- ) byte store */
void do_bytestore ()
{
	char * addr = (char *) data_pop();
	*addr = data_pop();
}

/* C@ ( addr -- ) byte fetch */
void do_bytefetch ()
{
	char * addr = (char *) data_pop();
	data_push(*addr);
}

/* CMOVE ( src_addr dest_addr len -- ) block byte copy */
void do_cmove ()
{
	long length = data_pop();
	char * dest_addr = (char *) data_pop();
	char * src_addr = (char *) data_pop();
	memcpy(dest_addr, src_addr, length);
}

void test_data_stack ()
{ 
	int i;
	int n = 100;
	for (i = 0; i < n; i++)
	{
		data_push(i);
		assert(data_top() == i);
	}
	for (i = 0; i < n; i++)
	{
		long x = data_pop();
		assert(x == (n-1-i));
	} 

	int a = 1, b = 20, c = 300;

	data_push(a);
	data_push(b);
	/* ( a b ) */

	do_over();
	/* ( a b a ) */
	assert(data_pop() == a);
	assert(data_pop() == b);
	assert(data_pop() == a);

	data_push(a);
	data_push(b);
	data_push(c);
	/* ( a b c ) */

	do_rot();
	assert(data_top() == b);
	/* ( c a b ) */

	do_rot();
	assert(data_top() == a);
	/* ( b c a ) */

	do_rot();
	assert(data_top() == c);
	/* ( a b c ) */

	do_irot();
	assert(data_top() == a);
	/* ( b c a ) */

	do_irot();
	assert(data_top() == b);
	/* ( c a b ) */

	do_irot();
	assert(data_top() == c);
	/* ( a b c ) */
	
	/* Clear the stack and check */
	assert(data_pop() == c);
	assert(data_pop() == b);
	assert(data_pop() == a); 
}

void test_return_stack ()
{
	int i;
	int n = 100;
	for (i = 0; i < n; i++)
	{
		returns_push(i);
	}
	for (i = 0; i < n; i++)
	{
		long x = returns_pop();
		assert(x == (n-1-i));
	}
} 

void memory_init ()
{ 
	var_S0 = xmalloc(sizeof(*var_S0) * 1000);
	dsp = var_S0;
	var_R0 = xmalloc(sizeof(*var_R0) * 1000);
	rsp = var_R0;
}

int main (int argc, char ** argv)
{ 
	memory_init();

	//test_data_stack();
	//test_return_stack();
	string_copy_null_to_length_test();

	return 0;
}
