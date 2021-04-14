#include <stdint.h>
#include <stddef.h>

struct WordHeader {
	struct WordHeader * link;
	struct {
		char len_flags;
		char chars[31];
	} name;
	void * code;
	void * params[];
};

void * pstack[32];
void * rstack[64];

void * ip;
void * xt;
void * pstack_ptr;
void * rstack_ptr;

void rpush (void * x) {
	*rstack_ptr-- = x;
}

void * rpop () {
	return ++*rstack_ptr;
}

void push (void * x) {
	*pstack_ptr-- = x;
}

void * pop () {
	return ++*pstack_ptr;
}

void enter () {
	rpush(ip);
	ip = *ip;
	next();
}

void next () {
	ip++;
}

void kernel_main (uint32_t r0, uint32_t r1, uint32_t atags) {

}

