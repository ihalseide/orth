/*
 * FemtoForth version 0.0.2
 *
 * by Izak Halseide
 */

/* Only 1 dependency: a few I/O functions */
#include <stdio.h>

/* Data type definitions */
typedef int cell;
typedef long dcell;
typedef unsigned char byte;
#define CELL_SIZE (sizeof(cell))

/* Reserved memory sizes */
#define MEMORY_SIZE 65536
#define DSTACK_SIZE 256
#define RSTACK_SIZE 64
#define READ_BUFFER 32 

/* Description of memory layout */
#define LATEST_POS READ_BUFFER
#define HERE_POS (LATEST_POS + CELL_SIZE)
#define BASE_POS (HERE_POS + CELL_SIZE)
#define STATE_POS (BASE_POS + CELL_SIZE)
#define DSTACK_POS (STATE_POS + CELL_SIZE)
#define RSTACK_POS (DSTACK_POS + DSTACK_SIZE * CELL_SIZE)
#define HERE_START (RSTACK_POS + RSTACK_SIZE * CELL_SIZE)

byte memory [MEMORY_SIZE];

int main (int argc, char ** argv)
{
	/* Setup the data stack */
	data_stack = (cell *) malloc(100 * (sizeof (cell)));
	data_stack_base = data_stack;

}
