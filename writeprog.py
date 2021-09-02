#!/usr/bin env python3

from ops import *

filename = input("filename to write to: ")

name_to_byte = {fn.__name__:i for i, fn in enumerate(funcs)}
binary = bytearray()

word = input('> ')
while word:
    if word in name_to_byte:
        x = num_free_bytes + name_to_byte[word]
    else:
        try:
            x = int(word)
        except ValueError:
            print('ignored invalid word!')
            continue
    binary.append(x)
    print(x)
    word = input('> ')

with open(filename, 'wb') as outfile:
    outfile.write(binary)
print("wrote to", filename)
