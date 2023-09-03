#! /usr/bin/python3
import numpy as np
import matplotlib.pyplot as plt
import json

with open('../config/simulation.json') as config_file:
    config = json.load(config_file)

File = config['File']
Sim = config['Simulation']

path = File['path']
name = input('\nInsert input file name: ')
ext = File['extension']
comment = input('Insert comments: ')
file_name = path + '/' + name + '.' + ext

N = int(Sim['N'])
a = float(Sim['start'])
b = float(Sim['stop'])
m = float(Sim['mean_value'])
s = float(Sim['dev_std'])

p1 = float(Sim['param1'])
p2 = float(Sim['param2'])
p3 = float(Sim['param3'])

x_u = np.random.uniform(a, b, N)
Dx = float(Sim['bin_size'])
M = (b - a)/Dx
H = plt.hist(x_u, bins=np.arange(a, b + Dx, Dx), density=True, alpha=0.5)
freq = H[0]
counts = H[0]*(N*Dx)
x = (Dx/2)*np.ones(len(H[0]))+H[1][:len(H[1])-1]


f_expression = Sim['f(x)']
def f(x):
    return eval(f_expression)

Dn = []
for i in range(0, len(x)):
    fm = f(x[i])
    Dn.append((counts[i] - N*Dx*fm)/(1 - Dx*fm))

n_new = counts - Dn

cont = []
for i in range(0, len(n_new)):
    cont.append(int(n_new[i]))

x_f = []
for i in range(0, len(cont)):
    unif = np.random.uniform(x[i] - Dx/2, x[i] + Dx/2, cont[i])
    for j in range(0, len(unif)):
        x_f.append(unif[j])

t = np.linspace(0,1,len(x_f))

with open(file_name, "w+") as file:
    file.write("t\tx\n")
    file.write("\t" + comment + "\n")
    for k in range(0, len(x_f)):
        file.write("%.6f\t%.6f\n"%(t[k], x_f[k]))
file.close()
with open(path + '/' + name + '.out', "a") as file:
    file.write("N_u\tN_f\n")
    file.write("\t" + comment + "\n")
    file.write("%i\t%i\n"%(N, len(x_f)))
    file.write("#-------------\n")
file.close()


