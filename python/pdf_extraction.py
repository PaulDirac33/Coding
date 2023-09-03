#!/usr/bin/python3
import matplotlib.pyplot as plt
import numpy as np
import json
import time

with open('/Users/riccardo/github/Coding/config/pdf_extraction.json') as config_file:
    config = json.load(config_file)

File = config['File']
Ext = config['Extraction']

path_in = File['path_in']
path_out = File['path_out']
name = input('\nInsert input file name: ')

tic = time.time()

ext = File['extension']
un = File['units']
a = float(Ext['start'])
b = float(Ext['stop'])
h = float(Ext['bin_size'])
column_y = int(Ext['column_y'])

file_name = path_in + '/' + name + '.' + ext
file_in = open(file_name, 'r')
data = file_in.readlines()

Y = []
for index, line in enumerate(data):
    column = line.split()
    if index == 0:
        y_name = column[column_y]
    elif index == 1:
        y_comments = ''
        for i in range(0, len(column)):
            y_comments += column[i]
    elif index == 2:
        if un == 'yes':
            y_units = column[column_y]
        else:
            Y.append(float(column[column_y]))
    else:
        Y.append(float(column[column_y]))

Histo = plt.hist(Y, np.arange(a, b , h), density = 'True')
bins = Histo[1]
freq = Histo[0]
counts = h*len(Y)*Histo[0]
with open(path_out + '/' + name + '_dprob.' + ext, "w+") as file:
    file.write(y_name + '\tf(' + y_name + ')' + '\tcounts\n')
    file.write(' \t' + y_comments + '\n')
    if un == 'yes':
        file.write(y_units + "\t\n")
    for k in range(0, min(len(bins), len(freq))):
        file.write("%.6f\t%.6f\t%.3f\n"%(bins[k]+h/2,freq[k],counts[k]))
file.close()
toc = time.time()
Dt = toc - tic
if Dt > 0.01:
    print('\nTime: %.2f s\n'%Dt)
else:
    print('\nTime: %.2f ms\n'%(1000*Dt))