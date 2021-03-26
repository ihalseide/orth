/* FemtoForth.c
 * Intended C standard: C99.
 */

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <string.h>

#define K *1024

long * dsp;
long * rsp;
long * var_S0; 
long * var_R0; 
long * memory;

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

void ds_push (long x)
{
	*dsp = x;
	dsp++;
}

long ds_pop ()
{
	dsp--;
	return *dsp;
}

long ds_top ()
{
	return *(dsp-1);
} 

void rs_push (long x)
{
	*rsp = x;
	rsp++;
}

long rs_pop ()
{
	rsp--;
	return *rsp;
} 

long rs_top ()
{
	return *(rsp-1);
}


char next_char ()
{
	return getchar();
}

int perform_char_code (char x)
{
	long * long_addr;
	char * char_addr;
	switch (x) {
		case '#':
			// Read number until a space is reached
			{
				long value = 0;
				int base = 36;
				char c = next_char();
				while (char_to_value(c) >= 0)
				{
					value *= base;
					value += char_to_value(c);
				}
				break;
			}
		case '\\':
			// Push the value of the next char
			ds_push(next_char());
			break;
		case '+':
			ds_push(ds_pop() + ds_pop());
			break;
		case '-':
			ds_push(ds_pop() - ds_pop());
			break;
		case '*':
			ds_push(ds_pop() * ds_pop());
			break;
		case '%':
			ds_push(ds_pop() % ds_pop());
			break;
		case '/':
			ds_push(ds_pop() / ds_pop());
			break;
		case '0':
			ds_push(0);
			break;
		case '1':
			ds_push(1);
			break;
		case '~':
			// Bitwise invert
			ds_push(~ ds_pop());
			break;
		case '&':
			// Bitwise and
			ds_push(ds_pop() & ds_pop());
			break;
		case '^':
			// Bitwise xor
			ds_push(ds_pop() ^ ds_pop());
			break;
		case '|':
			// Bitwise or
			ds_push(ds_pop() | ds_pop());
			break;
		case '@': 
			// Fetch
			ds_push(*((long *) ds_pop()));
			break;
		case '!': 
			// Store
			long_addr = (long *) ds_pop();
			*long_addr = ds_pop();
			break;
		case 'f': 
			// Byte-fetch
			ds_push(*((char *) ds_pop()));
			break;
		case '$':
			// Byte-store
			char_addr = (char *) ds_pop();
			*char_addr = ds_pop(); 
			break;
		case '`': 
			// Dup
			ds_push(ds_top()); 
			break;
		case 'x':
			{
				// Swap
				long a = ds_pop();
				long b = ds_pop();
				ds_push(a);
				ds_push(b);
				break;
			}
		case '_':
			// Drop
			ds_pop();
			break;
		case '=':
			// Equal
			ds_push(ds_pop() == ds_pop());
			break;
		case '>':
			// Less-than ( a b -- a>b )
			ds_push(ds_pop() < ds_pop());
			break;
		case '<':
			// Greater-than ( a b -- a<b )
			ds_push(ds_pop() > ds_pop());
			break;
		case 'o':
			// Over ( a b -- a b a )
			ds_push(*(dsp-2));
			break;
		case 'M':
			{
				// CMOVE
				long length = ds_pop();
				char * dest_addr = (char *) ds_pop();
				char * src_addr = (char *) ds_pop();
				memcpy(dest_addr, src_addr, length);
				break;
			}
		case 'k':
			// Key ( -- k )
			ds_push((char) getchar());
			break;
		case 'e':
			// Emit ( k -- )
			putchar((char) ds_pop());
			break;
		case '?':
			{
				// ?DUP ( x -- x x ) | ( 0 -- 0 )
				long t = ds_top();
				if (t != 0) {
					ds_push(t);
				}
				break;
			}
		case 'R':
			// R0
			ds_push((long) var_R0);
			break;
		case 'r':
			{
				// RSP!, RSP@, >R, and R>
				// maps to
				// r!,   r@,   r<, and r>
				char modifier = next_char();
				switch (modifier) {
					case '!': // RSP!
						rsp = (long *) ds_pop();
						break;
					case '@': // RSP@
						ds_push((long) rsp);
						break;
					case '<': // >R 
						rs_push(ds_pop());
						break;
					case '>': // R>
						ds_push(rs_pop());
						break;
				}
				break; 
			}
		case 's':
			{
				// DSP! and DSP@
				char modifier = next_char();
				switch (modifier) {
					case '!': // DSP!
						dsp = (long *) ds_pop();
						break;
					case '@': // DSP@
						ds_push((long) dsp);
						break;
				}
				break;
			}
		case 'S':
			// S0 
			ds_push((long) var_S0);
			break;
		case ' ':
		case '\n':
		case '\t':
			// Ignore whitespace (unless a number is being read)
			break;
		default:
			// Error code
			return -1;
			break;
	}
	// No error
	return 0; 
} 

void memory_init ()
{ 
	var_S0 = xmalloc(sizeof(*var_S0) * 1000);
	dsp = var_S0;
	var_R0 = xmalloc(sizeof(*var_R0) * 1000);
	rsp = var_R0;
	memory = xmalloc(sizeof(long) * 10 K);
}

int main (int argc, char ** argv)
{ 
	memory_init();

	char c = next_char();
	while (c != 'z')
	{
		perform_char_code(c);
		next_char();
	}

	return 0;
}
