
# FORTH word
# U. ( u -- )

def u_dot (n, base=10):
    # Invalid base
    if base < 2 or base > 36:
        return

    if n == 0:
        print(end='0')
        return

    i = 0
    num_buf = [0] * 33

    num_buf[0] = ord('0')

    # Extract digits based on the number base
    if base == 2:
        while n:
            num_buf[i] = n & 0b1
            i += 1
            n = n >> 1
    elif base == 4:
        while n:
            num_buf[i] = n & 0b11
            i += 1
            n = n >> 2
    elif base == 8:
        while n:
            num_buf[i] = n & 0b111
            i += 1
            n = n >> 3
    elif base == 16:
        while n:
            num_buf[i] = n & 0b1111
            i += 1
            n = n >> 4
    elif base == 32:
        while n:
            num_buf[i] = n & 0b11111
            i += 1
            n = n >> 5
    else:
        while n:
            q, r = divmod(n, base)
            num_buf[i] = r
            i += 1
            n = q

    # Print the number buffer
    for j in range(i-1, -1, -1):
        c = num_buf[j]
        if c > 9:
            c += ord('A') - ord('9') - 1
        c = chr(ord('0')+c)
        print(end=c)

base = 16
N = 1000
for n in range(N+1):
    u_dot(n, 10)
    print(end=' ')
    u_dot(n, 16)
    print()

