#!/usr/bin/python3
import time

N = int(input('\nInsert how many prime numbers you want to generate: '))

tic = time.time()								# start time

file = open("prime.dat", "w+")
file2 = open("primediff.dat", "w+")
file.write('n\t p_(n)\n')						# name
file.write(' \t Prime numbers\n')				#comments
file.write('1\t 2\n')
file2.write('n\t ∆_(n)\n')						# name
file2.write(' \t p_{n+1} - p_\\{n\\}\n')		#comments
n = 1											# prime number counter
p = 2   										# last prime number
i = 3
found = 'no'				
while n <= N -1:
	for j in range(2, i):
		 if i%j == 0:
		 	found = 'yes'
		 	break
	if found != 'yes':
		file2.write('%i\t %i\n'%(n, i - p))
		p = i
		n += 1
		file.write('%i\t %i\n'%(n, i))
		i += 1	
	else:
		found = 'no'
		i += 1 
toc = time.time()								# stop time
print('Execution time: %.3f s\n'%(toc - tic))