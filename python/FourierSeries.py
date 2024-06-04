#!/usr/bin/python3
import sympy as sp
import numpy as np
import matplotlib.pyplot as plt

def compute_fourier_series(f, xmin, xmax, n_max):
    # Definisci la variabile simbolica
    t = sp.symbols('t')
    
    # Calcola il coefficiente a0
    a0 = (1 / (xmax - xmin)) * sp.integrate(f, (t, xmin, xmax))
    
    # Calcola i coefficienti an
    an = [(1 / (xmax - xmin)) * sp.integrate(f * sp.cos(2 * np.pi * n * t / (xmax - xmin)), (t, xmin, xmax)).evalf() for n in range(1, n_max + 1)]
    
    # Calcola i coefficienti bn
    bn = [(1 / (xmax - xmin)) * sp.integrate(f * sp.sin(2 * np.pi * n * t / (xmax - xmin)), (t, xmin, xmax)).evalf() for n in range(1, n_max + 1)]
    
    # Calcola la serie di Fourier
    series = a0 / 2
    for n in range(1, n_max + 1):
        series += an[n - 1] * sp.cos(2 * np.pi * n * t / (xmax - xmin)) + bn[n - 1] * sp.sin(2 * np.pi * n * t / (xmax - xmin))
    
    # Plot della serie di Fourier
    t_values = np.linspace(xmin, xmax, 1000)
    series_values = np.array([series.subs(t, x) for x in t_values], dtype=float)
    plt.plot(t_values, series_values, color='red', linestyle='--', label='Fourier Series')
    
    # Plot della funzione periodica f(t)
    f_values = np.array([f.subs(t, x) for x in t_values], dtype=float)
    plt.plot(t_values, f_values, color='blue', label='f(t)')
    
    plt.xlabel('t')
    plt.ylabel('Value')
    plt.legend()
    plt.grid(True)
    plt.show()

# Definisci la funzione periodica f(t)
t = sp.symbols('t')
f = sp.Piecewise((t * sp.sin(t), (t >= -sp.pi / 2) & (t <= sp.pi / 2)), (0, True))

# Definisci gli estremi dell'intervallo
xmin = -np.pi
xmax = np.pi

# Numero di termini per l'approssimazione
n_max = 50

# Calcola la serie di Fourier e plotta
compute_fourier_series(f, xmin, xmax, n_max)
