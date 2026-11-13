#!/opt/homebrew/bin/python3

import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.widgets import Slider
import datetime

# === LETTURA CSV ===
df = pd.read_csv("../data/contability/masterbook.csv")

df["Date"] = pd.to_datetime(df["Date"], format="%d/%m/%Y")
df["Year"] = df["Date"].dt.year
df["DayOfYear"] = df["Date"].dt.dayofyear

day = df["Day"].tolist()
total_profit_extra = df["Total profit + extra"].tolist()

colors = plt.cm.tab10.colors

# === FIGURA 1 (grafico globale) ===
fig1, ax1 = plt.subplots(figsize=(8,5))
(line1,) = ax1.plot(day, total_profit_extra, marker="o", linestyle="-",
                    color="tab:blue", linewidth=2.5, markersize=5, markeredgewidth=2)
ax1.set_xlabel("Day")
ax1.set_ylabel("Total profit + extra")
ax1.set_title("Andamento profitti (globale)")
ax1.grid(alpha=0.3)

# === FIGURA 2 (grafico per anno) ===
fig2, ax2 = plt.subplots(figsize=(8,5))
year_lines, year_dots = {}, {}
for i, (year, group) in enumerate(df.groupby("Year")):
    x = group["DayOfYear"].tolist()
    y = group["Total profit + extra"].tolist()
    line, = ax2.plot(x, y, linestyle="-", linewidth=2.5,
                     color=colors[i % len(colors)], label=str(year))
    dot, = ax2.plot([], [], "o", markersize=12,
                    markerfacecolor="black",
                    markeredgecolor=colors[i % len(colors)],
                    markeredgewidth=2, zorder=5)
    year_lines[year] = (line, x, y)
    year_dots[year] = dot

vline = ax2.axvline(1, color="gray", linestyle="--", linewidth=2)
ax2.set_xlabel("Day of Year")
ax2.set_ylabel("Total profit + extra")
ax2.set_title("Andamento profitti (per anno)")
ax2.grid(alpha=0.3)
ax2.legend()

# Tooltip per il grafico annuale
tooltip = ax2.annotate("", xy=(0,0), xytext=(20,20),
                       textcoords="offset points",
                       bbox=dict(boxstyle="round", fc="w", ec="0.5", alpha=0.9),
                       arrowprops=dict(arrowstyle="->"))
tooltip.set_visible(False)

# === FIGURA 3 (finestra controlli) ===
fig_ctrl, ax_ctrl = plt.subplots(figsize=(8,3))
plt.subplots_adjust(left=0.1, right=0.9)
ax_ctrl.axis("off")

# Slider X min/max
ax_xmin = plt.axes([0.1, 0.55, 0.65, 0.05])
ax_xmax = plt.axes([0.1, 0.45, 0.65, 0.05])
s_xmin = Slider(ax_xmin, 'X min', 0, max(day), valinit=min(day))
s_xmax = Slider(ax_xmax, 'X max', 0, max(day), valinit=max(day))

# Slider Y min/max
ax_ymin = plt.axes([0.1, 0.25, 0.65, 0.05])
ax_ymax = plt.axes([0.1, 0.15, 0.65, 0.05])
s_ymin = Slider(ax_ymin, 'Y min', -1.1*max(total_profit_extra), 1.1*max(total_profit_extra), valinit=min(total_profit_extra))
s_ymax = Slider(ax_ymax, 'Y max', -1.1*max(total_profit_extra), 1.1*max(total_profit_extra), valinit=max(total_profit_extra))

# Slider per retta verticale
ax_dayline = plt.axes([0.1, 0.75, 0.65, 0.05])
s_dayline = Slider(ax_dayline, 'Day of Year', 1, 366, valinit=1, valstep=1)

# === CALLBACKS ===
def update_axes(val):
    ax1.set_xlim(s_xmin.val, s_xmax.val)
    ax1.set_ylim(s_ymin.val, s_ymax.val)
    ax2.set_ylim(s_ymin.val, s_ymax.val)
    fig1.canvas.draw_idle()
    fig2.canvas.draw_idle()

s_xmin.on_changed(update_axes)
s_xmax.on_changed(update_axes)
s_ymin.on_changed(update_axes)
s_ymax.on_changed(update_axes)

def update_dayline(val):
    day_pos = int(s_dayline.val)
    vline.set_xdata([day_pos, day_pos])
    texts = []
    tooltip.set_visible(False)
    for year, (line, x, y) in year_lines.items():
        if day_pos in x:
            idx = x.index(day_pos)
            year_dots[year].set_data([x[idx]], [y[idx]])
            date_real = datetime.datetime(year, 1, 1) + datetime.timedelta(days=day_pos-1)
            texts.append(f"{year}: {date_real.strftime('%d %b')} → {y[idx]:,.2f} €")
        else:
            year_dots[year].set_data([], [])
    if texts:
        tooltip.set_text("\n".join(texts))
        tooltip.xy = (day_pos, max(y))
        tooltip.set_visible(True)
    fig2.canvas.draw_idle()

s_dayline.on_changed(update_dayline)

plt.show()
