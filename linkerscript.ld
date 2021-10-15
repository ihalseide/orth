/******************************************************************************
*	kernel.ld
*	 by Alex Chadwick
*  (MODIFIED)
*	A linker script for generation of raspberry pi kernel images.
******************************************************************************/

SECTIONS {
	.init 0x8000 : {
		*(.init)
	}
	
	/* 
	* Next we put the rest of the code.
	*/
	.text : {
		*(.text)
	}
	
	/* 
	* Next we put the data.
	*/
	.data : {
		*(.data)
	}
}

