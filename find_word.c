
typedef struct word {
} word;

// (addr1 -- addr2 flag)

void find (void) {
	void * r0 = pop();
	word * r1 = var_latest;
	int r2 = r0->length;
	r0 = (char *) r0 + 1;
	while (r1 != 0) {

		// compare name lengths
		int r3 = r1->length;
		if (r2 != r3) {
			continue;
		}

		// compare characters
		while (r3 > 0) {
			int r4 = r2 - r3;
			if (r4 > r2) {
				// out of bounds
				break;
			}

			char r5 = r1->name[r4]; 
			char r6 = r0->name[r4];
			if (r5 != r6) {
				r3--;
				continue;
			}

			// found match

		}

		r1 = r1->prev;
	}

	// not found

}
