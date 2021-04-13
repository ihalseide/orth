= My forth for Raspberry Pi, ARM v71 =

Forth in assembler language by Izak Nathanael Halseide

== System Features ==

* cooperate with Linux OS
* spaces are the only non-word character
* buffered input
* immediate mode: run code at compile time
* word headers only guaranteed at compile time
** challenge: how to variables and constants? see C?
* word headers include name, source code, and compiled code
* words can have names up to a 31-characters long
* compile ARM code
* save word headers at run time only if desired

== Library Features ==

* music synthesis
* arrays
* file I/O

== Command Line Interface ==

* Command synopsis
 Usage: forth [-h | -v | -i] [-c file] [file | -] [args]
 Run the forth interpreter or compiler with or without input and output files.
 Options:
     -h, --help         show this help message and exit
     -v, --version      show version number and exit
     -i, --interactive  start the interpreter after running a source program
     -h, --headless     when compiling, do not save the dictionary
     -c file            compile the source program into file
     file               source program read from a file, also marks the
                        beginning of args
     -                  source program read from stdin (default file)
     args               arguments to pass when running a source program and when
                        running the interactive interpreter
 Examples:
     forth               run the interpreter in interactive mode
     forth p             run the program, p
     forth -i prog       run prog and then enter interactive mode
     forth -c exec prog  compile prog to exec


== Word header structure ==

 struct WordHeader {
     struct WordHeader * link;
     struct {
         char len_flags;  // binary: ffflllll
         char name[31];
     } name;
     void * code_field;
     ExecutionToken params[];
 }


