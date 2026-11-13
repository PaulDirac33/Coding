import numpy as np
import matplotlib.pyplot as plt
import time
import sys
import os

# Uso:
#   python3 plot_live.py file1.dat Rs1 file2.dat Rs2 ...

args = sys.argv[1:]
if len(args) < 2 or len(args) % 2 != 0:
    print("Usa: python3 plot_live.py file1.dat Rs1 file2.dat Rs2 ...")
    sys.exit(1)

files = [(args[i], float(args[i+1])) for i in range(0, len(args), 2)]

plt.ion()
fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(11,5))

def load_data(filename):
    try:
        data = np.loadtxt(filename, skiprows=2)
    except:
        return None

    if data.ndim == 1 or data.shape[1] < 2:
        return None

    Vs = data[:,0]     # prima colonna
    Vl = data[:,1]     # seconda colonna
    return Vs, Vl


while True:
    ax1.clear()
    ax2.clear()

    for fname, Rs in files:
        if not os.path.exists(fname):
            continue

        loaded = load_data(fname)
        if loaded is None:
            continue
        
        Vs, Vl = loaded

        # ======== GRAFICO 1 (come tuo codice originale) ========
        ax1.plot(Vs, Vl, "o", markersize=6, label=os.path.basename(fname))
        ax1.set_xlabel("Vs (Vpp)")
        ax1.set_ylabel("Vl (Vpp)")
        ax1.grid(True)

        # ======== GRAFICO 2 richiesto ========
        i = Vs / (2*Rs)                # A
        V = (Vs + Vl) / 2              # Vpp/2 → ampiezza equivalente

        ax2.plot(i*1000, V, "o", markersize=7, label=f"{os.path.basename(fname)}  Rs={Rs}Ω")

    ax1.legend()
    ax2.legend()
    ax2.set_xlabel("Corrente i (mA)")
    ax2.set_ylabel("V = (Vs + Vl) / 2 (V)")
    ax2.grid(True)

    plt.draw()
    plt.pause(1)
