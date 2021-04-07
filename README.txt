= My forth for Raspberry Pi, ARM v71 =

Forth in assembler language by Izak Nathanael Halseide

== System Features ==

* cooperate with Linux OS
* spaces are the only non-word character
* buffered input
* immediate mode: run code at compile time
* word headers only guaranteed at compile time
    * challenge: how to variables and constants? see C?
* word headers include name, source code, and compiled code
* words can have names up to a 31-characters long
* compile ARM code
* save word headers at run time only if desired

== Library Features ==

* music synthesis
* arrays
* file I/O

== Word header structure ==

 struct WordHeader {
     struct WordHeader * link;
     struct {
         char len_flags;  // binary: ffflllll
         char name[31];
     } name;
     void * code_field;
     void * code_field2;
     ExecutionToken params[];
 }


