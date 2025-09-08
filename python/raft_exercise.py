# raft_exercise.py
from manim import *
import math

# --------------------------
# Config per formato verticale Instagram/iPhone (9:16)
# --------------------------
config.pixel_width = 1080
config.pixel_height = 1920
config.frame_width = 7.2
config.frame_height = 12.8
config.background_color = "#1f1f1f"

# --------------------------
# Parametri del problema
# --------------------------
m1, m2, m3 = 42.3, 45.2, 48.3
M = m1 + m2 + m3
rho_water = 1020.0
rho_wood = 757.5
D, L = 0.320, 1.77
g = 9.81
N_theoretical = 4 * M / ((rho_water - rho_wood) * math.pi * D**2 * L)
Pm = M * g / (4 * D * L)

def fmt(x, n=4):
    return f"{x:.{n}g}"

# --------------------------
# Funzione automatica di scaling
# --------------------------
def autoscale(mobj: Mobject, margin=0.2) -> Mobject:
    """
    Ridimensiona automaticamente se l'oggetto eccede i limiti del frame.
    Considera i margini attorno ai bordi.
    """
    max_w = config.frame_width * (1 - margin)
    max_h = config.frame_height * (1 - margin)
    factor = 1.0
    if mobj.width > max_w:
        factor = min(factor, max_w / mobj.width)
    if mobj.height > max_h:
        factor = min(factor, max_h / mobj.height)
    if factor < 1.0:
        mobj.scale(factor)
    return mobj

# --------------------------
# Scene
# --------------------------
class RaftScene(Scene):
    def construct(self):
        # Sfondo
        bg = FullScreenRectangle(fill_color=config.background_color, fill_opacity=1.0)
        self.add(bg)

        # Titolo (pulito, centrato)
        title = autoscale(
            Text("Zattera di tronchi — soluzione completa",
                 font_size=40, color=WHITE, weight=BOLD)
        )
        title.to_edge(UP, buff=0.5)
        self.play(FadeIn(title))

        self.wait(0.5)

        # --------------------
        # BLOCCO 1: Dati
        dati = VGroup(
            MathTex(rf"m_1 = {m1}\ \mathrm{{kg}},\ m_2 = {m2}\ \mathrm{{kg}},\ m_3 = {m3}\ \mathrm{{kg}}").scale(0.8),
            MathTex(rf"\rho_{{acqua}} = {int(rho_water)}\ \mathrm{{kg/m^3}},\ \rho_{{legno}} = {fmt(rho_wood,6)}\ \mathrm{{kg/m^3}}").scale(0.8),
            MathTex(rf"D = {D}\ \mathrm{{m}},\ L = {L}\ \mathrm{{m}}").scale(0.8),
            MathTex(rf"M = m_1 + m_2 + m_3 = {fmt(M,5)}\ \mathrm{{kg}}").scale(0.8)
        ).arrange(DOWN, aligned_edge=LEFT, buff=0.3)
        autoscale(dati)
        dati.next_to(title, DOWN, buff=0.8)
        self.play(Write(dati))
        self.wait(2)
        self.play(FadeOut(dati))

        # --------------------
        # BLOCCO 2: Geometria
        geo = VGroup(
            Text("Geometria della sezione immersa", font_size=32, color=WHITE),
            MathTex(r"S = \tfrac{1}{2}\,\theta R^2").scale(0.8),
            MathTex(r"A_0 = R\sin\!\left(\tfrac{\theta}{2}\right)\cos\!\left(\tfrac{\theta}{2}\right)").scale(0.8),
            MathTex(r"A_{cm} = S - A_0").scale(0.8),
            MathTex(r"A_{im} = \pi R^2 - A_{cm} = \tfrac{R^2}{2}(2\pi-\theta+\sin\theta)").scale(0.8)
        ).arrange(DOWN, aligned_edge=LEFT, buff=0.3)
        autoscale(geo)
        geo.next_to(title, DOWN, buff=0.8)
        self.play(Write(geo))
        self.wait(2.5)
        self.play(FadeOut(geo))

        # --------------------
        # BLOCCO 3: Equilibrio
        eq = VGroup(
            Text("Condizione di equilibrio", font_size=32, color=WHITE),
            MathTex(r"N\rho_{acqua}A_{im}L - N\rho_{legno}\tfrac{\pi D^2}{4}L = M").scale(0.75),
            MathTex(r"\text{Caso limite: } \theta \to 0").scale(0.7),
            MathTex(r"N = \tfrac{4M}{(\rho_{acqua}-\rho_{legno})\pi D^2 L}").scale(0.8),
            MathTex(rf"N \approx {fmt(N_theoretical,4)} \Rightarrow N_{{\min}} = 4").scale(0.9).set_color(GREEN)
        ).arrange(DOWN, aligned_edge=LEFT, buff=0.3)
        autoscale(eq)
        eq.next_to(title, DOWN, buff=0.8)
        self.play(Write(eq))
        self.wait(2.5)
        self.play(FadeOut(eq))

        # --------------------
        # BLOCCO 4: Risultati
        box = RoundedRectangle(
            corner_radius=0.3, height=3.0, width=config.frame_width*0.85,
            fill_color="#111111", fill_opacity=0.8
        )
        autoscale(box)
        box.move_to(ORIGIN)

        res_title = Text("Risultati finali", font_size=30, color=WHITE, weight=BOLD)
        autoscale(res_title)
        res_title.next_to(box.get_top(), DOWN, buff=0.3)

        res_items = VGroup(
            MathTex(r"N_{\min} = 4", font_size=36).set_color(GREEN),
            MathTex(rf"P_m \approx {fmt(Pm,6)}\,\mathrm{{Pa}}", font_size=36).set_color(YELLOW)
        ).arrange(DOWN, buff=0.3)
        autoscale(res_items)
        res_items.move_to(box.get_center()).shift(DOWN*0.1)

        self.play(Create(box), FadeIn(res_title), FadeIn(res_items))
        self.wait(2)

        nota = Text("Nota: si assume peso distribuito uniformemente\nsulla superficie ≈ N·D·L",
                    font_size=24, color=GREY)
        autoscale(nota)
        nota.next_to(box, DOWN, buff=0.4)
        self.play(FadeIn(nota))
        self.wait(2)

        thanks = Text("Fine — pronto per la voce narrante", font_size=28, color=WHITE)
        autoscale(thanks)
        thanks.to_edge(DOWN, buff=0.5)
        self.play(FadeIn(thanks))
        self.wait(2)
