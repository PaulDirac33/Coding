#!/usr/bin/python3
N = 25
a = 0
b = 1

print(f"Primi {N} numeri della serie di Fibonacci:")
print(f"{'i = 1':<10} --> {a:>6}")
print(f"{'i = 2':<10} --> {b:>6}")
i = 3
while i <= N:
    c = a + b
    print(f"{'i = ' + str(i):<10} --> {c:>6}")
    a = b
    b = c
    i += 1
