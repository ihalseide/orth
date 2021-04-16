#include <stdio.h>

/* pad array to use */
char pad [33];

/* global base */
int base = 10;

/* n -> u
 * where u is length
 * writes string result into the pad
 */
unsigned int n_to_str (int n) {
	char d;
	char negative = 0;
	unsigned int i = 0;

	/* Error */
	if (base < 2) {
		return 0;
	}

	/* Trivial case of 0 */
	if (n == 0) {
		pad[0] = 48;
		return 1;
	}

	/* Handle negatives */
	if (n < 0) {
		negative = 1;
		n = -n;
	}

	switch (base) {
		case 2:
			while (n != 0) {
				pad[i] = n & 1;
				n = n >> 1;
				i++;
			}
			break;
		case 4:
			while (n != 0) {
				pad[i] = n & 3;
				n = n >> 2;
				i++;
			}
			break;
		case 8:
			while (n != 0) {
				pad[i] = n & 7;
				n = n >> 3;
				i++;
			}
			break;
		case 16:
			while (n != 0) {
				pad[i] = n & 15;
				n = n >> 4;
				i++;
			}
			break;
		case 32:
			while (n != 0) {
				pad[i] = n & 31;
				n = n >> 5;
				i++;
			}
			break;
		default:
			while (n != 0) {
				pad[i] = n % base;
				n = n / base;
				i++;
			}
			break;
	}

	/* Add a minus sign if it was negative */
	if (negative) {
		/* Weird value because of conversion in the following loop */
		pad[i] = -3; 
		i += 1;
	}

	/* Reverse the output string */
	int x = 0;
	int y = i - 1;
	char e;
	while (x <= y) {
		/* Get the characters on the opposite sides of the array */
		d = pad[x];
		e = pad[y];

		/* Convert values to digits */
		if (d > 9) {
			d = d + 7;
		}
		if (e > 9) {
			e = e + 7;
		}
		d = d + 48;
		e = e + 48;

		/* Swap characters */
		pad[y] = d;
		pad[x] = e;

		/* Move indices towards each other */
		x++;
		y--;
	}

	return i;
}

void wrap (int n) {
	unsigned int i, len;
	len = n_to_str(n);
	for (i = 0; i < len; i++) {
		putchar(pad[i]);
	}
}

int main () {
	int i;
	for (base = 0; base < 36; base++) {
		printf("base %d:\n", base);
		for (i = -100; i <= 100; i++) {
			wrap(i);
			putchar(' ');
		}
		printf("\n");
	}
	return 0;
}

