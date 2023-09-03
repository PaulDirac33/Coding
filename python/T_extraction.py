#!/usr/bin/python3

import numpy as np
import matplotlib.pyplot as plt
import json
import time

with open('/Users/riccardo/github/Coding/config/T_extraction.json') as config_file:
    config = json.load(config_file)

File = config['File']
Ext = config['Extraction']

path_in = File['path_in']
path_out = File['path_out']
name = input('\nInsert input file name: ')

tic = time.time()

ext = File['extension']
shift = int(Ext['shift'])
comments = Ext['comments']
column_comments = int(Ext['column_comments'])
units = Ext['units']
start_line = int(Ext['start_line'])
column_x = int(Ext['column_x'])
column_y = int(Ext['column_y'])

file_path = path_in + '/' + name + '.' + ext   
data = []
info = []
def read_file(file_path = file_path):
    with open(file_path, 'r') as file:
        current_line = 0
        for line in file:
            if current_line < start_line:
                information = line.strip().split()
                info.append(information)
                current_line += 1
            else:
                columns = line.strip().split()
                data.append(columns)
                current_line += 1

    return data
file_in = read_file()
N = len(file_in)
x = []
y = []
for i in range(0, N):
    x.append(float(file_in[i][column_x]))
    y.append(float(file_in[i][column_y]))
Dx = x[20] - x[19]
def f(t):
    for n in range(0, len(t)):
        if n == 0:
            if t[0] == 0:
                n += 1
            else:
                return t
        else:
            if t[n] == 0:
                n += 1
            else:
                return(t[n:])

z = f(y)

def g(t):
    M = []
    T =[]
    found_the_first = 'no'
    for m in range(1, len(t)):
        if t[m] == 0:
            m += 1
        else:
            if found_the_first == 'no':
                T.append(m)
                M.append(m)
                found_the_first = 'yes'
                m += 1
            else:
                T.append(m-M[len(M)-1])
                M.append(m)
                m += 1
        
    return(T)

with open(path_out + '/' + name + '_T.' + ext, 'w+') as file:
    file.write('T\n')
    file.write(info[0][column_y - shift] + '\t')
    if comments == 'yes':
        file.write(info[1][column_comments] + '\n')
    else:
        file.write('\n')
    if units == 'yes':
        file.write(info[2][column_x - shift] + '\n')      
    for i in range(0, len(g(z))):
        file.write('%.3f\n'%(Dx*g(z)[i]))

file.close()
toc = time.time()
Dt = toc - tic
if Dt > 0.01:
    print('\nTime: %.2f s\n'%Dt)
else:
    print('\nTime: %.2f ms\n'%(1000*Dt))
