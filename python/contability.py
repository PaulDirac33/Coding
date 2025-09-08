#!/usr/bin/python3
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.widgets import Slider
import datetime as dt

# === LETTURA CSV ===
df = pd.read_csv("../data/contability/masterbook.csv")

# Parse date e calcola day of year
df["Date"] = pd.to_datetime(df["Date"], format="%d/%m/%Y")
df["Year"] = df["Date"].dt.year
df["DayOfYear"] = df["Date"].dt.dayofyear

# Dati generali (per il primo grafico)
day = df["Day"].tolist()
total_profit_extra = df["Total profit + extra"].tolist()

# === CREAZIONE FIGURA CON 2 GRAFICI ===
fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14,5))
plt.subplots_adjust(left=0.1, bottom=0.25, wspace=0.3)

# --- GRAFICO 1 (stesso di prima) ---
(line1,) = ax1.plot(day, total_profit_extra, marker="o", linestyle="-", color="blue")
ax1.set_xlabel("Day")
ax1.set_ylabel("Total profit + extra")
ax1.set_title("Andamento profitti (globale)")
ax1.set_xlim(min(day), max(day))
ax1.set_ylim(min(total_profit_extra), max(total_profit_extra))
ax1.grid(True)

# --- GRAFICO 2 (separato per anno) ---
colors = plt.cm.tab10.colors  # palette
year_lines = {}
year_dots = {}

for i, (year, group) in enumerate(df.groupby("Year")):
    x = group["DayOfYear"].tolist()
    y = group["Total profit + extra"].tolist()
    line, = ax2.plot(x, y, linestyle="-", color=colors[i % len(colors)], label=str(year))
    dot, = ax2.plot([], [], "o", markersize=10, 
                    markerfacecolor="black", 
                    markeredgecolor=colors[i % len(colors)])
    year_lines[year] = (line, x, y)
    year_dots[year] = dot

vline = ax2.axvline(1, color="gray", linestyle="--")  # retta verticale
ax2.set_xlabel("Day of Year")
ax2.set_ylabel("Total profit + extra")
ax2.set_title("Andamento profitti (per anno)")
ax2.grid(True)
ax2.legend()

# === SLIDER ZONE ===
axcolor = 'lightgoldenrodyellow'
ax_xmin = plt.axes([0.1, 0.1, 0.35, 0.03], facecolor=axcolor)
ax_xmax = plt.axes([0.55, 0.1, 0.35, 0.03], facecolor=axcolor)
ax_ymin = plt.axes([0.1, 0.05, 0.35, 0.03], facecolor=axcolor)
ax_ymax = plt.axes([0.55, 0.05, 0.35, 0.03], facecolor=axcolor)

s_xmin = Slider(ax_xmin, 'X min', 0, max(day), valinit=min(day))
s_xmax = Slider(ax_xmax, 'X max', 0, max(day), valinit=max(day))
s_ymin = Slider(ax_ymin, 'Y min', -1.1*max(total_profit_extra), 1.1*max(total_profit_extra), valinit=min(total_profit_extra))
s_ymax = Slider(ax_ymax, 'Y max', -1.1*max(total_profit_extra), 1.1*max(total_profit_extra), valinit=max(total_profit_extra))

# Slider per la retta verticale (giorno dell’anno)
ax_dayline = plt.axes([0.3, 0.9, 0.4, 0.03], facecolor=axcolor)
s_dayline = Slider(ax_dayline, 'Day of Year', 1, 366, valinit=1, valstep=1)

# === FUNZIONI UPDATE ===
def update_axes(val):
    ax1.set_xlim(s_xmin.val, s_xmax.val)
    ax1.set_ylim(s_ymin.val, s_ymax.val)
    ax2.set_ylim(s_ymin.val, s_ymax.val)  # stesso asse y per il secondo
    fig.canvas.draw_idle()

s_xmin.on_changed(update_axes)
s_xmax.on_changed(update_axes)
s_ymin.on_changed(update_axes)
s_ymax.on_changed(update_axes)

def update_dayline(val):
    day_pos = int(s_dayline.val)
    vline.set_xdata([day_pos, day_pos])
    # Aggiorna punti su ogni curva
    for year, (line, x, y) in year_lines.items():
        if day_pos in x:
            idx = x.index(day_pos)
            year_dots[year].set_data([x[idx]], [y[idx]])
        else:
            year_dots[year].set_data([], [])
    fig.canvas.draw_idle()

s_dayline.on_changed(update_dayline)

plt.show()
