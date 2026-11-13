#!/usr/bin/python3
l = 10
rho = 1.68E-8
v_rms = 230
i_rms = 14.5
eps = 5E-2

S = (2*rho*l)*(i_rms/(v_rms*eps))
print(S*1E6)