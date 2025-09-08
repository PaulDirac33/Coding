#!/opt/homebrew/bin/python3
import numpy as np
from scipy.integrate import quad

# Definizione dell'integrando
def integrand(s):
    return (s**4 * np.exp(s)) / ((np.exp(s) - 1)**2)

# Funzione f(x)
def f(x):
    integral, _ = quad(integrand, 0, 1/x)
    return 3 * x**3 * integral

# Generazione dei punti (x, y)
def generate_points(N, filename="../data/debye.dat"):
    xs = np.linspace(0.01, 5, N)
    ys = [f(x) for x in xs]
    data = np.column_stack((xs, ys))
    np.savetxt(filename, data, fmt="%.8f")
    print(f"Salvati {N} punti in {filename}")

if __name__ == "__main__":
    N = 100  # numero di punti, modificabile
    generate_points(N)
