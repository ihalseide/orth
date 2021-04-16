
/* pad array to use */
extern char * pad;

/* global base */
extern int base;

/* u1 -> u2
 * where u2 is length
 * writes string result into the pad
 */
unsigned int u_to_str (unsigned int u) {
	/* Base error */
	if (base < 2) {
		return 0;
	}

	/* Index into the pad */
	unsigned int i = 0;

	/* Clear pad to be zero in case n==0 */
	if (u == 0) { 
		i = 1;
		pad[0] = 0;
	}

	switch (base) {
		case 2:
			while (u != 0) {
				pad[i] = u & 1;
				u = u >> 1;
				i++;
			}
			break;
		case 4:
			while (u != 0) {
				pad[i] = u & 3;
				u = u >> 2;
				i++;
			}
			break;
		case 8:
			while (u != 0) {
				pad[i] = u & 7;
				u = u >> 3;
				i++;
			}
			break;
		case 16:
			while (u != 0) {
				pad[i] = u & 15;
				u = u >> 4;
				i++;
			}
			break;
		case 32:
			while (u != 0) {
				pad[i] = u & 31;
				u = u >> 5;
				i++;
			}
			break;
		default:
			while (u != 0) {
				pad[i] = u % base;
				u = u / base;
				i++;
			}
			break;
	}

	/* Reverse the output string */
	u = 0;
	int j = i;
	while (u <= j) {
		/* Get the characters on the opposite sides of the array */
		char c, d;
		c = pad[u];
		d = pad[j];

		/* Convert values to digits */
		if (c > 9) { c = c + 7; }
		if (d > 9) { d = d + 7; }
		c = c + '0';
		d = d + '0';

		/* Swap characters */
		pad[j] = c;
		pad[u] = d;

		/* Move indices towards each other */
		u++;
		j--;
	}

	return i;
}

