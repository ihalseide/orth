	/* Macro for defining a word header 
	 */
	.macro define name, namelen, flags=0, label
	.text
	.align 2
	.global name_\label
name_\label:
	.word link
	.set link, name_\label
	.byte \flags+\namelen
	.ascii "\name"
	.space 31-\namelen
	.align 2
	.global xt_\label
xt_\label:
	.endm

	/* Macro for defining code to go with a word header
	 */
	.macro code label
	.word \label
	.text
	.align 2
\label:
	.endm

	/* Macro for variables definition
	 */
	.macro var label, initial
	.word dovar
	.word var_\label
	.data
	.align 2
	.global var_\label
var_\label:
	.word \initial
	.endm

	/* Macro for constants definition
	 */
	.macro constant label, value
	.word doconst
	.global const_\label
const_\label:
	.word \value
	.endm

