#!/usr/bin/python3
import sys

def filtra_file(file_in, file_out,v_min, v_max, i_min, i_max):
    with open(file_in, 'r') as f_in, open(file_out, 'w') as f_out:
        f_out.write('V\tI\n')
        f_out.write('mV\tµA\n')
        for l in f_in:
            c = l.strip().split('\t')
            if len(c) >= 2:
                v = float(c[0])
                i = float(c[1])
                if v_min <= v <= v_max and i_min <= i <= i_max:
                    f_out.write(l)
                    
path = sys.argv[1]+'/'
array = sys.argv[2]
file_in = path + array+'.txt'
file_out = path + array+'_exp.txt'
v_min = 1.570176814859
def v_max(x):
    if x == 'BB':
        return 266.7937112079
    if x == 'Ref':
        return 261.2016487358
i_min = 5.189756049242
i_max = 8.385605605623

filtra_file(file_in, file_out,v_min, v_max(array), i_min, i_max)
