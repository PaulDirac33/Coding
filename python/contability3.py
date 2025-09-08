#!/opt/homebrew/bin/python3
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.widgets import Slider, CheckButtons
import datetime

# === LETTURA CSV ===
df = pd.read_csv("../data/contability/masterbook.csv")
df["Date"] = pd.to_datetime(df["Date"], format="%d/%m/%Y")
df["Year"] = df["Date"].dt.year
df["Month"] = df["Date"].dt.month

colors = plt.cm.tab10.colors

# === AGGREGAZIONE MENSILE ===
monthly = df.groupby(["Year", "Month"]).agg({"In":"sum", "Out":"sum"}).reset_index()

# === FUNZIONE COSTRUZIONE CURVE ===
def build_curves(ax, column, ylabel, title):
    ax.set_title(title)
    ax.set_xlabel("Mese")
    ax.set_ylabel(ylabel)
    ax.set_xlim(1, 12)
    ax.grid(alpha=0.3)

    lines = {}
    for i, (year, group) in enumerate(monthly.groupby("Year")):
        x = group["Month"]
        y = group[column]
        (line,) = ax.plot(x, y, linewidth=2, marker="o",
                          color=colors[i % len(colors)], label=str(year))
        lines[year] = line

    return lines

# === FIGURA ENTRATE ===
fig_in, ax_in = plt.subplots(figsize=(9,5))
lines_in = build_curves(ax_in, "In", "Entrate €", "Entrate mensili")

# === FIGURA USCITE ===
fig_out, ax_out = plt.subplots(figsize=(9,5))
lines_out = build_curves(ax_out, "Out", "Uscite €", "Uscite mensili")

# === FIGURA CONTROLLI ===
fig_ctrl, ax_ctrl = plt.subplots(figsize=(4,6))
plt.subplots_adjust(left=0.3)
ax_ctrl.axis("off")

# CheckButtons per accendere/spegnere curve
labels = [str(y) for y in sorted(df["Year"].unique())]
visibility = [True]*len(labels)
rax = plt.axes([0.05, 0.4, 0.25, 0.5])
check = CheckButtons(rax, labels, visibility)

def toggle(label):
    year = int(label)
    vis = not lines_in[year].get_visible()
    lines_in[year].set_visible(vis)
    lines_out[year].set_visible(vis)
    fig_in.canvas.draw_idle()
    fig_out.canvas.draw_idle()

check.on_clicked(toggle)

# Slider per il mese
ax_slider = plt.axes([0.1, 0.1, 0.8, 0.05])
s_month = Slider(ax_slider, "Mese", 1, 12, valinit=1, valstep=1)

# Annotazioni dinamiche (tooltip)
ann_in = ax_in.annotate("", xy=(0,0), xytext=(15,15),
                        textcoords="offset points", ha="center",
                        bbox=dict(boxstyle="round,pad=0.3", fc="yellow", alpha=0.7),
                        arrowprops=dict(arrowstyle="->"))
ann_in.set_visible(False)

ann_out = ax_out.annotate("", xy=(0,0), xytext=(15,15),
                          textcoords="offset points", ha="center",
                          bbox=dict(boxstyle="round,pad=0.3", fc="yellow", alpha=0.7),
                          arrowprops=dict(arrowstyle="->"))
ann_out.set_visible(False)

# === FUNZIONE UPDATE TOOLTIP ===
def update(val):
    month = int(s_month.val)
    ann_in.set_visible(False)
    ann_out.set_visible(False)

    for year in sorted(df["Year"].unique()):
        if not lines_in[year].get_visible():
            continue

        row = monthly[(monthly["Year"]==year) & (monthly["Month"]==month)]
        if row.empty:
            continue

        xin, yin = month, row["In"].values[0]
        xout, yout = month, row["Out"].values[0]

        ann_in.xy = (xin, yin)
        ann_in.set_text(f"{month:02d}/{year}\nEntrate: {yin:.2f} €")
        ann_in.set_visible(True)

        ann_out.xy = (xout, yout)
        ann_out.set_text(f"{month:02d}/{year}\nUscite: {yout:.2f} €")
        ann_out.set_visible(True)

    fig_in.canvas.draw_idle()
    fig_out.canvas.draw_idle()

s_month.on_changed(update)

plt.show()
