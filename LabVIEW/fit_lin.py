#!/usr/bin/python3
import numpy as np
import matplotlib.pyplot as plt
import pandas as pd
import json

with open('../../config/scope.json', 'r') as file:
    config_data = json.load(file)

File = config_data['File']
Ext = config_data['Extraction']

path_out = File['path_out']+'/'
Imin = int(File['start'])
Imax = int(File['stop'])


for k in range(Imin, Imax + 1):
	print(k)
	with open(path_out + 'CH2_' + str(k) + '.dat', 'r') as header_file:
		header_lines = [header_file.readline().strip(), header_file.readline().strip()]
	
	data1 = np.loadtxt(path_out + 'CH2_' + str(k) + '.dat', skiprows=2)
	x1 = data1[:, 0]
	y1 = data1[:, 1]


	data2 = np.loadtxt(path_out + 'CH1_' + str(k) + '.dat', skiprows=2)
	x2 = data2[:, 0]
	y2 = data2[:, 1]


	m = len(x1)
	n = len(x2)
	y_out = []
	for i in range(0, n):
		d = []
		for j in range(0, m):
			d.append(abs(x1[j] - x2[i]))

		min_index, min_value = min(enumerate(d), key=lambda x: x[1])
		if x2[i] - x1[min_index] > 0:
			j2 = min_index
			j1 = j2 - 1
		if x2[i] - x1[min_index] < 0:
			j1 = min_index
			j2 = j1 + 1
		else:
			j2 = min_index
			j1 = j2
		if j1 == j2:
			y_out.append(y1[j1])
		else:
			y_out.append(y1[j2] + (x2[i] - x1[j2])*((y1[j2] - y1[j1])/(x1[j2] - x1[j1])))

	with open(path_out + 'CH2_' + str(k) + '.dat', 'w+') as file_out:
		file_out.write(header_lines[0] + '\n')
		file_out.write(header_lines[1] + '\n')
		for i in range(0, n):
			file_out.write('%.6f\t%.6f\n'%(x2[i], y_out[i]))