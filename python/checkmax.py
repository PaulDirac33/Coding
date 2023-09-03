#!/usr/bin/python3

import numpy as np
T = 20
tol = 0.01
tau = 1
dx = 0.001
x = np.arange(0, 5 * T + dx, dx)

def Y(t):
    k = np.floor(t / (T + np.random.uniform(-0.1, 0.1)))  # Calcola il numero di periodi completi trascorsi con distanziamento casuale
    t_relative = t - k * (T + np.random.uniform(-0.1, 0.1))  # Calcola il tempo relativo all'interno del periodo corrente

    y_t = np.exp(-((t_relative - tau) / (tau / 2)) ** 2)  # Impulso gaussiano con deviazione standard tau

    return y_t

y = Y(x)

y = Y(x)
dy = []
for i in range(0, len(y) - 1):
	dy.append((y[i+1] - y[i])/dx)

maxima = []
counter = 0
for i in range (0, len(dy)):
	if abs(dy[i]) > tol:
		if counter > 1:
			maxima[i-1] = 0
			maxima.append(0)
			counter = 0
		else:
			maxima.append(0)
			counter = 0
	else:
		counter += 1
		maxima.append(y[i])



with open('checkmax_y.dat', 'w+') as file:
	file.write('x\ty\n')
	for i in range(0, len(y)):
		file.write('%.3f\t%.3f\n'%(x[i],y[i]))
with open('checkmax_z.dat', 'w+') as file:
	file.write('x\tdy/dx\n')
	for i in range(0, len(dy)):
		file.write('%.3f\t%.3f\n'%(x[i],dy[i]))
with open('checkmax.dat', 'w+') as file:
	file.write('x\tM\n')
	for i in range(0, len(maxima)):
		file.write('%.3f\t%.3f\n'%(x[i],maxima[i]))