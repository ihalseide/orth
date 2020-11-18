/* FemtoForth.c
 * Intended compilation command (C99):
 * `gcc -g -std=c99 -Wall -Werror'
 */

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <string.h>

/* Characters allocated for a word buffer */
#define WORD_BUF_SIZE 31

/* Memory layout and allocation values  */
#define DATA_STACK_SIZE 1000 
#define RETURN_STACK_SIZE 100
#define ADDITIONAL_MEMORY 1972 

typedef struct Arena {
	char * ptr;
	char * end;
	char ** blocks
} Arena; 

void * arena_alloc (Arena * arena, size_t size)
{
	if (size > (size_t)(arena->end - arena->ptr))
	{
		arena_grow(arena, size);
		assert(size <= (size_t)(arena->end - arena->ptr));
	}

	void * ptr = arena->ptr;
	arena->ptr = ALIGN_UP_PTR(arena->ptr + size, ARENA_ALIGNMENT);

	assert(arena->ptr <= arena->end);
	assert(ptr == ALIGN_DOWN_PTR(ptr, ARENA_ALIGNMENT)a);
	
	return ptr;
}

void arena_grow (Arena * arena, size_t min_size)
{
	size_t size = align_up(clamp_min(min_size, ARENA_BLOCK_SIZE), ARENA_ALIGNMENT);
	arena->ptr = xmalloc(size);
	assert(arena->ptr == ALIGN_DOWN_PTR(arena->ptr, ARENA_ALIGNMENT));
	arena->end = arena->ptr + size;
	buf_push(arena->blocks, arena->ptr);
}

void arena_free (Arena * arena)
{
	for (char **it = arena->blocks; it != buf_end(arena->blocks; it++))
	{
		free(*it);
	}
	buf_free(arena->blocks);
}

typedef struct F_String
{
	long length;
	char content [0];
}
F_String;

/* Word dictionary headers */
typedef struct WordHeader
{
	unsigned char length;
	unsigned char is_immediate;
	unsigned char is_hidden;
	char name [16];
	void (* code)(void);
}
WordHeader;

/* The two stacks,
 * data stack,
 * and return stack
 */
long * data_stack;
long * var_S0; 
long * return_stack;
long * var_R0; 
long ** memory;
WordHeader * word_dictionary;

/* Global buffers for certain functions */
char word_buffer [WORD_BUF_SIZE];

/* Forth variables:
 * S0 is the minimum value for data stack ptr
 */
long var_State;
long var_Here;
long var_Latest;
long var_Base = 10; 

void word_dictionary_init ()
{ 
	word_dictionary = malloc(sizeof(*word_dictionary) * 256);
}

bool is_space (char x)
{
	switch (x)
	{
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

void data_push (long x)
{
	*data_stack = x;
	data_stack++;
}

long data_pop ()
{
	data_stack--;
	return *data_stack;
}

long data_top ()
{
	return *(data_stack-1);
}

void data_init ()
{
	data_stack = (long * ) malloc(sizeof(*data_stack) * DATA_STACK_SIZE);
	var_S0 = data_stack;
}

void returns_init ()
{
	return_stack = malloc(sizeof(*return_stack) * RETURN_STACK_SIZE);
	var_R0 = return_stack;
}

void returns_push (long x)
{
	*return_stack = x;
	return_stack++;
}

long returns_pop ()
{
	return_stack--;
	return *return_stack;
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
	data_push(*(data_stack-2));
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
	data_push((long) return_stack);
}

void do_DSP_fetch ()
{
	data_push((long) data_stack);
}

void do_RSP_store ()
{
	return_stack = (long *) data_pop();
}

void do_DSP_store ()
{
	data_stack = (long *) data_pop();
}

/* emit ( c -- ) */
void do_emit ()
{
	putchar(data_pop());
}

char _key ()
{
	char c = getchar();
	return c;
}

/* key ( -- c ) */
void do_key ()
{
	data_push(_key());
}

/* Skip leading spaces and backslash characters as its own word. */
/* Return the last char read, which is an actual word char */
char skip_whitespace ()
{
	char c = _key();
	while (is_space(c) || c == '\\')
	{
		if (c == '\\')
		{
			while (c != '\n')
			{
				c = _key();
			}
			continue;
		}
		c = _key();
	}
	return c;
}

/* Reads a word from stdin into the word buffer */
long _word ()
{
	char c = skip_whitespace();
	int index = 0;
	while (index < WORD_BUF_SIZE && !is_space(c))
	{
		word_buffer[index] = c;
		index++;
		c = _key();
	} 
	return index; // as length
}

/* word ( -- addr length ) */
void do_word ()
{
	long length = _word();
	data_push((long) word_buffer);
	data_push(length);
}

/* ( addr length -- n e ) convert a string into a number, where
 * 	n is the number, and
 * 	e is the number of unparsed characters
 */
long do_number ()
{
	int length = (int) data_pop();
	char * addr = (char *) data_pop();

	if (length <= 0)
		goto error;

	long value = 0;
	int sign = 1;
	char * c = addr;

	for (c = addr; length > 0; c++, length--)
	{
		value *= var_Base;
		if (*c == '-')
		{
			sign = -1;
			if (length <= 1) /* Error: you can't have just a minus sign */
				goto error;
			continue;
		} 

		int x = char_to_value(*c); 
		if (0 <= x && x < var_Base) 
			value += x;
		else
			break; 
	}
	value *= sign;
	data_push(value);
	data_push(length);
	return value; 

error: 
	data_push(0);
	data_push(length);
	return 0;
}

void * do_find ()
{
	return NULL;
}


/* `[' (left bracket) changes the interpreter to immediate mode */
void do_lbracket ()
{
	var_State = INTERPRET_MODE_IMMEDIATE;
}

/* `]' (right bracket) changes the interpreter to compile mode */
void do_rbracket ()
{
	var_State = INTERPRET_MODE_COMPILE;
}

/* tell ( addr length -- ) */
void do_tell ()
{
	int length = (int) data_pop();
	char * addr = (char *) data_pop();
	fwrite(addr, sizeof(char), length, stdout);
}

/* char ( -- c ) push the ascii code of the first letter of the next word */
void do_char ()
{
	do_word();
	long len = data_pop();
	long addr = data_pop();
	if (len)
		data_push(*((char *) addr));
}

long bool_to_langbool (bool b)
{
	if (b)
	{
		return F_TRUE;
	}
	return F_FALSE; 
}

/* Quick! math operators */
void do_add () { data_push(data_pop() + data_pop()); } 
void do_sub () { data_push(-data_pop() + data_pop()); } 
void do_mul () { data_push(data_pop() * data_pop()); } 
void do_negate () { data_push(-data_pop()); } 
void do_double () { data_push(data_pop() * 2); }
void do_halve () { data_push(data_pop() / 2); }
/* Increment and decrement */
void do_incr () { data_push(data_pop() + 1); } 
void do_decr () { data_push(data_pop() - 1); } 
/* Comparison values */
void do_true () { data_push(F_TRUE); } 
void do_false () { data_push(F_FALSE); }
/* Comparison operators */
void do_equ () { data_push(bool_to_langbool(data_pop() == data_pop())); } 
void do_neq () { data_push(bool_to_langbool(data_pop() != data_pop())); }
void do_lt  () { data_push(bool_to_langbool(data_pop() <  data_pop())); }
void do_gt  () { data_push(bool_to_langbool(data_pop() >  data_pop())); }
void do_le  () { data_push(bool_to_langbool(data_pop() <= data_pop())); }
void do_ge  () { data_push(bool_to_langbool(data_pop() >= data_pop())); }
/* Comparison with zero */
void do_zequ () { data_push(bool_to_langbool(data_pop() == 0));}
void do_zneq () { data_push(bool_to_langbool(data_pop() != 0));}
void do_zlt  () { data_push(bool_to_langbool(data_pop() <  0));}
void do_zgt  () { data_push(bool_to_langbool(data_pop() >  0));}
void do_zle  () { data_push(bool_to_langbool(data_pop() <= 0));}
void do_zge  () { data_push(bool_to_langbool(data_pop() >= 0));}
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

/* +! ( value addr -- ) add store */
void do_addstore ()
{
	long * addr = (long *) data_pop();
	*addr += data_pop();
}

/* -! ( value addr -- ) sub store */
void do_substore ()
{
	long * addr = (long *) data_pop();
	*addr -= data_pop();
}

/* C! ( value addr -- ) byte store */
void do_bytestore ()
{
	unsigned char * addr = (unsigned char *) data_pop();
	*addr = data_pop();
}

/* C@ ( addr -- ) byte fetch */
void do_bytefetch ()
{
	unsigned char * addr = (unsigned char *) data_pop();
	data_push(*addr);
}

/* C@C! ( src_addr dest_addr -- ) byte copy */
void do_bytecopy ()
{
	unsigned char * dest_addr = (unsigned char *) data_pop();
	unsigned char * source_addr = (unsigned char *) data_pop();
	*dest_addr = *source_addr;
}

/* CMOVE ( src_addr dest_addr len -- ) block byte copy */
void do_cmove ()
{
	long length = data_pop();
	unsigned char * dest_addr = (unsigned char *) data_pop();
	unsigned char * src_addr = (unsigned char *) data_pop();
	memcpy(dest_addr, src_addr, length);
}

/* Create an F_String with a the maximum length of the smallest of
 * the strlen of the cstring
 * or the given length.
 */
/* WARNING: this overwrites a temporary string buffer, which can invalidate
 * pointers that result from calling this function.
 */
void fstring_from_c (F_String * out, char * cstring, int length)
{
	static char buffer [1024];
	char * c = cstring;
	int cstring_len = 0;
	while (*(c++) && (c-cstring <= length))
	{
		*buffer++ = *c;
		cstring_len++;
	}
	result->contents = *buffer;
	// Minimum
	result->length = (length > cstring_len) ? cstring_len : length;
} 

void word_create_c
(const char * cname,
 bool is_immediate,
 bool is_hidden,
 void (*func)(void))
{
	int length = strlen(cname);
	char name[DICT_WORD_LENGTH] = cstring_to_fstring(cname, DICT_WORD_LENGTH);
	WordHeader h = {length, is_immediate, is_hidden, name, func};
	*word_dictionary = h;
}

void do_DOCOL ()
{
	// TODO: implement
}

/* Creates DOCOL definitions for Forth words */
void word_create_forth
(const char * cname,
 bool is_immediate,
 bool is_hidden,
 long * code_start,
 int code_length)
{
	F_String = cstring_to_fstring(cname);	
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

void test_io ()
{ 
	int i;
	char msg[32] = "test_emit is good!\n ok.\n";
	for (i = 0; i < 32; i++)
	{
		if (!msg[i]) break;
		data_push(msg[i]);
		do_emit();
	}

	printf("test_echo> ");
	do_key();
	do_emit();
	printf(" ok.\n");
	printf("word> ");
	do_word();
	int len = data_pop();
	char * addr = (char *) data_pop();
	printf("Length: %d, address: %p, string: '", len, addr);
	fwrite(word_buffer, sizeof(char), len, stdout);
	printf("'.\n");

	int old_base = var_Base;

	var_Base = 10;
	printf("base10> ");
	do_word();
	do_number();
	printf("err(%d) #:%ld\n", (int) data_pop(), (long) data_pop());

	var_Base = 16;
	printf("base16> ");
	do_word();
	do_number();
	printf("err(%d) #:%ld\n", (int) data_pop(), (long) data_pop());

	var_Base = 36;
	printf("base36> ");
	do_word();
	do_number(); 
	printf("err(%d) #:%ld\n", (int) data_pop(), (long) data_pop());

	var_Base = old_base;
}


int main (int argc, char ** argv)
{
	data_init();
	returns_init();
	word_dictionary_init();

	test_data_stack();
	test_return_stack();
	test_io();

	return 0;
}
