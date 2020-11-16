exe="forth.exe"
src="femtoforth.c"
errorf="errors.txt"

EDITOR=/usr/bin/vim
export EDITOR

# Clean
if [ -f $exe ];
	then rm $exe;
fi
if [ -s $errorf ];
	then rm $errorf;
fi

# Build
gcc -o $exe -g -std=c99 -Wall -Werror $src 2> $errorf 

# Run:
# view the error file if it is not empty,
# otherwise run gdb
if [ -s $errorf ];
then
	view $errorf;
else
	gdb $exe;
fi
