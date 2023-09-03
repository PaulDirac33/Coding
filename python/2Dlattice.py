#!/usr/bin/python3
import numpy as np
import matplotlib.pyplot as plt

a = 1
b = 1

a1 = [a, 0]
a2 = [0, b]

d1 = [0,0]
d2 = [a/2, b/2]

n1_min = 0
n1_max = 99
n2_min = 0
n2_max = 101
with open("../data/2Dlattice_2at.dat", "w+") as file:
	file.write('x\ty\tx\ty\n')
	file.write('\tRect_lattice\n')
	file.write('Angstrom\tAngstrom\tAngstrom\tAngstrom\n' )
	
	for i in range(n1_min, n1_max+1):
		for j in range(n2_min, n2_max+1):
			file.write('%.4f\t%.4f\t'%(d1[0]+i*a1[0]+j*a2[0], d1[1]+i*a1[1]+j*a2[1]))
			file.write('%.4f\t%.4f\n'%(d2[0]+i*a1[0]+j*a2[0], d2[1]+i*a1[1]+j*a2[1]))
			
file.close()