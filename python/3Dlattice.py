#!/usr/bin/python3
import numpy as np
import matplotlib.pyplot as plt

a = 2
b = 2
c = 2

# a1 = [a/2, a/2, 0]	# FCC
# a2 = [b/2, 0, b/2]
# a3 = [0, c/2, c/2]

a1 = (2*np.pi/a)*np.array([-1,1,1])
a2 = (2*np.pi/a)*np.array([1,-1,1])
a3 = (2*np.pi/a)*np.array([1,1,-1])
d1 = [0,0,0]
d2 = [a/2, b/2, c/2]

n1_min = -5
n1_max = 5
n2_min = 0
n2_max = 5
n3_min = 0
n3_max = 5
with open("../data/3Dlattice_a1.dat", "w+") as file:
	file.write('x\ty\tz\n')
	file.write('\t\tbcc_lattice_atom1\n')
	file.write('\t\tAngstrom\n' )
	for i in range(n1_min, n1_max+1):
		for j in range(n2_min, n2_max+1):
			for k in range(n3_min, n2_max+1):
				file.write('%.4f\t%.4f\t%.4f\n'%(d1[0]+i*a1[0]+j*a2[0]+k*a3[0], d1[1]+i*a1[1]+j*a2[1]+k*a3[1], d1[2]+i*a1[2]+j*a2[2]+k*a3[2]))		
file.close()
m1_min = 0
m1_max = 1
m2_min = 0
m2_max = 1
m3_min = 0
m3_max = 1
with open("../data/3Dlattice_a2.dat", "w+") as file:
	file.write('x\ty\tz\n')
	file.write('\t\tbcc_lattice_atom2\n')
	file.write('\t\tAngstrom\n' )
	for i in range(m1_min, m1_max+1):
		for j in range(m2_min, m2_max+1):
			for k in range(m3_min, m2_max+1):
				file.write('%.4f\t%.4f\t%.4f\n'%(d2[0]+i*a1[0]+j*a2[0]+k*a3[0], d2[1]+i*a1[1]+j*a2[1]+k*a3[1], d2[2]+i*a1[2]+j*a2[2]+k*a3[2]))		
file.close()