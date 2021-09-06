#include <assert.h>
#include <stdio.h>

// Virtual Machine
// * Shared memory for code and data
// * Instructions - 1 byte

#define PS_SIZE 64
#define RS_SIZE 128
typedef struct VM {
	char halted;  // boolean/flag
	long pc;      // program counter
	long *ps;     // parameter stack
	long *rs;     // return stack
	long mem_len; // memory
	char *mem;
} VM;

// VM *vm_new (char *mem, int mem_len) {
// 	VM *new = malloc(sizeof(VM));
// 	vm_init(new, mem, mem_len);
// 	return new;
// }

void vm_init (VM *vm, long *ps, long *rs, char *mem, int mem_len) {
	vm->pc = 0;
	vm->halted = 0;
	vm->ps = ps;
	vm->rs = rs;
	vm->mem_len = mem_len;
	vm->mem = mem;
}

void vm_step (VM *self);

void vm_run (VM *self) {
	while(!self->halted && (0 <= self->pc < self->mem_len)) {
		vm_step(self);
	}
}

void vm_steps (VM *self, int n) {
	while(!self->halted && (n > 0) && (0 <= self->pc < self->mem_len)) {
		vm_step(self);
		n--;
	}
}

void rpush (VM *self, long x) {
	*self->rs = x;
	self->rs++;
}

long rpop(VM *self) {
	self->rs--;
	return *self->rs;
}

void push (VM *self, long x) {
	*self->ps = x;
	self->ps++;
}

long pop(VM *self) {
	self->ps--;
	return *self->ps;
}

// Opcodes:

void noop (VM *self) { }

void add (VM *self) {
	long b = pop(self);
	long a = pop(self);
	push(self, a + b);
}

void sub (VM *self) {
	long b = pop(self);
	long a = pop(self);
	push(self, a - b);
}

void mul (VM *self) {
	long b = pop(self);
	long a = pop(self);
	push(self, a * b);
}

void div (VM *self) {
	long b = pop(self);
	long a = pop(self);
	push(self, a / b);
}

void mod (VM *self) {
	long b = pop(self);
	long a = pop(self);
	push(self, a % b);
}

void drop (VM *self) {
	pop(self);
}

void swap (VM *self) {
	long temp = self->ps[-1];
	self->ps[-1] = self->ps[-2];
	self->ps[-2] = temp;
}

void nip (VM *self) {
	swap(self);
	pop(self);
}

void dup (VM *self) {
	push(self, self->ps[-1]);
}

void cfetch (VM *self) {
	self->ps[-1] = self->mem[self->ps[-1]];
}

void fetch (VM *self) {
	// TODO
}

void cstore (VM *self) {
	long a = pop(self);
	long b = pop(self);
	self->mem[a] = b;
}

void store (VM *self) {
	// TODO
}

void give (VM *self) {
	putchar((char)(255 & pop(self)));
}

void take (VM *self) {
	push(self, getchar());
}

void litc (VM *self) {
	// Literal char/byte
	self->pc += 1;
	push(self, self->mem[self->pc]);
}

void lit (VM *self) {
	// TODO
}

void equ (VM *self) {
	long b = pop(self);
	long a = pop(self);
	push(self, a == b);
}

void lt (VM *self) {
	long b = pop(self);
	long a = pop(self);
	push(self, b < a);
}

void gt (VM *self) {
	long b = pop(self);
	long a = pop(self);
	push(self, b > a);
}

void neg (VM *self) {
	self->ps[-1] = -self->ps[-1];
}

void not_ (VM *self) {
	self->ps[-1] = ~self->ps[-1];
}

void and_ (VM *self) {
	long b = pop(self);
	long a = pop(self);
	push(self, a & b);
}

void or_ (VM *self) {
	long b = pop(self);
	long a = pop(self);
	push(self, a | b);
}

void xor_ (VM *self) {
	long b = pop(self);
	long a = pop(self);
	push(self, a ^ b);
}

void branch (VM *self) {
	long a = self->mem[self->pc + 1];
	self->pc += a;
}

void maybe (VM *self) {
	self->pc += pop(self)? 0 : 1;
}

void halt (VM *self) {
	self->halted = 1;
}

void tor (VM *self) {
	rpush(self, pop(self));
}

void fromr (VM *self) {
	push(self, rpop(self));
}

void mswap (VM *self) {
	long b = pop(self);
	long a = pop(self);
	self->mem[a], self->mem[b] = self->mem[b], self->mem[a];
}

// Populate the list of the VM's operation functions
#define VM_FUNCS_LEN 31
void (* VM_FUNCS[VM_FUNCS_LEN])(VM *) = {
    noop, add, sub, mul,
    div, mod, drop, swap,
    nip, dup, cfetch, fetch,
    cstore, store, give, take,
    litc, lit, equ, lt,
    gt, neg, and_, or_,
    xor_, branch, maybe, halt,
    tor, fromr, mswap
};

void vm_step (VM *self) {
	if (self->halted) {
		return;
	}
	char x = self->mem[self->pc];
	void (* fn)(VM *vm) = VM_FUNCS[x];
	fn(self);
	self->pc++;
}

char encode (void (* x)(VM *)) {
    // Convert a VM function or int to an int
	for (char i = 0; i <= VM_FUNCS_LEN; i++) {
		if (x == VM_FUNCS[i]) {
			return i;
		}
	}
	assert(0);
	return -1;
}

int main (int argc, char **argv) {
	VM vm; // yes, not a pointer on purpose
	long ps[64];
	long rs[256];

    // Print an '*' asterisk
	#define PROG_LEN 4
	char prog1[PROG_LEN] = {
		encode(litc), '*', encode(give),
		encode(halt)
	};
	vm_init(&vm, ps, rs, prog1, PROG_LEN);
	vm_run(&vm);

    // Print out 'Hello, world!\n' to the terminal
	#define PROG_LEN 43
    char prog2[PROG_LEN] = {
        encode(litc), 'H', encode(give),
        encode(litc), 'e', encode(give),
        encode(litc), 'l', encode(give),
        encode(litc), 'l', encode(give),
        encode(litc), 'o', encode(give),
        encode(litc), ',', encode(give),
        encode(litc), ' ', encode(give),
        encode(litc), 'w', encode(give),
        encode(litc), 'o', encode(give),
        encode(litc), 'r', encode(give),
        encode(litc), 'l', encode(give),
        encode(litc), 'd', encode(give),
        encode(litc), '!', encode(give),
        encode(litc), '\n', encode(give),
        encode(halt),
	};
	vm_init(&vm, ps, rs, prog2, PROG_LEN);
	vm_run(&vm);
}

