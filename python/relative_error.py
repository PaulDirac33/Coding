#!/usr/bin/python3
import numpy as np
import matplotlib.pyplot as plt

N = 720
h = 0.1
D = 40

t = np.linspace(0, 24, N)

x = 10*np.exp(-(t - 13)**2/10)

y = x + 4*np.random.uniform(-h,h,N)
z = x + x*np.random.uniform(-h,h,N)



def relative_error(s1, s2, delta):
    E = []
    for n in range(delta, len(s1)):
        s = 0
        for m in range(n - delta, n):
            s += abs((s2[m] - s1[m])/(s1[m]))
        E.append(100*s/delta)
    
    return(E)

sol1 = relative_error(x, y, D)
sol2 = relative_error(x, z, D)

plt.plot(t, x, 'r--', label='x (model)', linewidth=2)  # x con linea rossa tratteggiata
plt.plot(t, y, 'k.', label='y (test)',  linewidth=0.5) 
plt.plot(t, z, 'b-', label='y (test)',  linewidth=1) 
plt.legend()
plt.show()

plt.plot(sol1[250:500], 'k.', linewidth=2)
plt.plot(sol2[250:500], 'b.', linewidth=2)
plt.plot(100*(h/2)*np.ones(250), 'b-', label='y (test)',  linewidth=1)
plt.plot(100*(h/2)*(4/x)[265:515], 'k-', label='y (test)',  linewidth=1) 
plt.show()

