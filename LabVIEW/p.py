#!/usr/bin/python3
import sys

path_in = sys.argv[1]
path_out = sys.argv[2]
Imin = sys.argv[3]
Imax = sys.argv[4]


channel = sys.argv[5]
Dx = sys.argv[6]
Dy = sys.argv[7]
x_units = sys.argv[8]
y_units = sys.argv[9]
name = 'CH'+channel

print(path_in)
print(path_out)
print(Imin)
print(Imax)
print(channel)
print(Dx)
print(Dy)
print(x_units)
print(y_units)
print(name)