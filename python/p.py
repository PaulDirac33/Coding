#!/usr/bin/python3
from mantid.simpleapi import *
import matplotlib.pyplot as plt
import numpy as np

print('--------------------')
file_path = '/Users/riccardo/github/Coding/data/ISIS_VESUVIO/pHEMA_10pc_transmission.nxs'
data_workspace = Load(file_path)

data = data_workspace.extractY()
print(len(data[0]))
x_values = data_workspace.extractX()
print(len(x_values[0]))
with open('/Users/riccardo/github/Coding/data/ISIS_VESUVIO/10pc_T.dat', 'w+') as file:
    file.write('Energy\t Transmission\n')
    file.write('pHEMA_10%H2O\n')
    file.write('meV\t \n')
    for i in range(0, len(data[0])):
        file.write('%.6f\t%.6f\n'%(x_values[0][i], data[0][i]))
print('--------------------')