# raft_exercise_paged_final_focus_fixed.py
from manim import *
import math

# --------------------------
# Config verticale Instagram/iPhone (9:16)
# --------------------------
config.pixel_width = 1080
config.pixel_height = 1920
config.frame_width = 7.2
config.frame_height = 12.8
config.background_color = "#000000"  # sfondo nero puro

# --------------------------
# Colori gradiente (più contrasto)
# --------------------------
LOGO_COLORS = ["#FFB347", "#FF6600", "#CC3300"]

def GradientTitle(text, font_size=46):
    """Titolo con gradiente e bordo bianco sottile.
    Un singolo Text con stroke, così colore+contorno compaiono insieme."""
    t = Text(
        text,
        font_size=font_size,
        weight=BOLD,
        gradient=LOGO_COLORS
    )
    # bordo bianco fine
    t.set_stroke(WHITE, width=2, opacity=1)
    return t

# --------------------------
# Parametri del problema (notazioni richieste)
# --------------------------
m1, m2, m3 = 42.3, 45.2, 48.3
M = m1 + m2 + m3
rho1 = 1020.0   # acqua -> ρ_1
rho2 = 757.5    # legno -> ρ_2
D, L = 0.320, 1.77
g = 9.81

N_theoretical = 4 * M / ((rho1 - rho2) * math.pi * D**2 * L)
Pm_value = M * g / (4 * D * L)

def fmt(x, n=4):
    return f"{x:.{n}g}"

# --------------------------
# Parametri animazione
# --------------------------
WRITE_RT = 1.8
LINE_WAIT = 0.12

# --------------------------
# Autoscale
# --------------------------
def autoscale(mobj: Mobject, margin=0.1) -> Mobject:
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
# Scene principale
# --------------------------
class RaftScene(Scene):
    def construct(self):
        # Sfondo nero
        bg = FullScreenRectangle(fill_color=config.background_color, fill_opacity=1.0)
        self.add(bg)

        # Titolo principale
        title = autoscale(GradientTitle("PROBLEMA DELLA ZATTERA DI TRONCHI", font_size=46))
        title.to_edge(UP, buff=0.4)
        self.play(Write(title, run_time=1.2))
        self.wait(0.6)

        # =================================================
        # Creazione blocchi
        # =================================================
        blocks = []

        # 1) Dati iniziali
        dati_block = VGroup(
            MathTex(rf"m_1 = {m1}\ \mathrm{{kg}},\quad m_2 = {m2}\ \mathrm{{kg}},\quad m_3 = {m3}\ \mathrm{{kg}}").scale(0.9),
            MathTex(rf"\rho_1 = {int(rho1)}\ \mathrm{{kg/m^3}},\quad \rho_2 = {fmt(rho2,6)}\ \mathrm{{kg/m^3}}").scale(0.9),
            MathTex(rf"D = {D}\ \mathrm{{m}},\quad L = {L}\ \mathrm{{m}}").scale(0.9),
            MathTex(rf"M = m_1 + m_2 + m_3 = {fmt(M,5)}\ \mathrm{{kg}}").scale(0.9)
        ).arrange(DOWN, aligned_edge=LEFT, buff=0.3)
        blocks.append(dati_block)

        # 2) Geometria
        geo_block = VGroup(
            GradientTitle("Geometria della sezione immersa", font_size=34),
            MathTex(r"S = \tfrac{1}{2}\,\theta R^2").scale(0.9),
            MathTex(r"A_{\Delta} = \tfrac{1}{2}R^{2}\sin\!\bigl(\tfrac{\theta}{2}\bigr)\cos\!\bigl(\tfrac{\theta}{2}\bigr)").scale(0.9),
            MathTex(r"A_{em} = S - A_{\Delta}").scale(0.9),
            MathTex(r"A_{im}(\theta) = \pi R^2 - A_{em} = \tfrac{R^2}{2}\,(2\pi - \theta + \sin\theta)").scale(0.9)
        ).arrange(DOWN, aligned_edge=LEFT, buff=0.3)
        blocks.append(geo_block)

        # 3) Condizione equilibrio
        eq_block = VGroup(
            GradientTitle("Condizione di equilibrio", font_size=34),
            MathTex(r"N \rho_1 A_{im}(\theta) L - N \rho_2 \tfrac{\pi D^2}{4} L = M").scale(0.85),
            MathTex(r"N \Bigl[\rho_1\,\tfrac{R^2}{2}(2\pi-\theta+\sin\theta)L - \rho_2\,\tfrac{\pi D^2}{4}L \Bigr] = M").scale(0.85)
        ).arrange(DOWN, aligned_edge=LEFT, buff=0.3)
        blocks.append(eq_block)

        # 4) Situazione limite
        N_formula = MathTex(r"N = \tfrac{4M}{(\rho_1-\rho_2)\,\pi D^2 L}").scale(0.9)
        N_value_line = MathTex(rf"N \approx {fmt(N_theoretical,4)} \;\Rightarrow\; N_{{\min}} = 4").set_color(BLUE).scale(0.9)
        limit_block = VGroup(
            GradientTitle("Situazione limite: tronchi a pelo d'acqua", font_size=34),
            MathTex(r"h = 0 \;\;\Longleftrightarrow\;\; \theta \to 0").scale(0.85),
            MathTex(r"N\,\tfrac{(\rho_1-\rho_2)\,\pi D^2}{4}L = M").scale(0.85),
            N_formula,
            N_value_line
        ).arrange(DOWN, aligned_edge=LEFT, buff=0.28)
        blocks.append(limit_block)

        # 5) Pressione media
        Pm_formula = MathTex(r"P_m = \tfrac{M g}{N D L}").scale(0.9)
        Pm_value_line = MathTex(rf"P_m \approx {fmt(Pm_value,6)}\ \mathrm{{Pa}}").set_color(BLUE).scale(0.9)
        press_block = VGroup(
            GradientTitle("Pressione media esercitata", font_size=34),
            Pm_formula,
            Pm_value_line
        ).arrange(DOWN, aligned_edge=LEFT, buff=0.28)
        blocks.append(press_block)

        # =================================================
        # Render
        # =================================================
        current_page = VGroup()
        current_height = title.height + 0.8
        max_height = config.frame_height * 0.85

        for block in blocks:
            autoscale(block)
            block_height = block.height + 0.6

            if current_height + block_height > max_height:
                self.play(FadeOut(current_page), run_time=1.0)
                current_page = VGroup()
                current_height = title.height + 0.8
                self.wait(0.2)

            if len(current_page) == 0:
                block.next_to(title, DOWN, buff=0.8, aligned_edge=LEFT)
            else:
                block.next_to(current_page[-1], DOWN, buff=0.6, aligned_edge=LEFT)

            for line in block:
                self.play(Write(line, run_time=WRITE_RT))
                self.wait(LINE_WAIT)

            current_page.add(block)
            current_height += block_height

        # =================================================
        # Svuoto la pagina ma tengo i risultati
        # =================================================
        to_fade = []
        for b in current_page:
            for line in b:
                if line in (N_value_line, Pm_value_line):
                    continue
                to_fade.append(line)
        if to_fade:
            self.play(FadeOut(VGroup(*to_fade)), run_time=1.2)
            self.wait(0.3)

        # =================================================
        # Box finale
        # =================================================
        box = RoundedRectangle(
            corner_radius=0.3, height=3.2, width=config.frame_width*0.9,
            stroke_color=BLUE, stroke_width=4,
            fill_color=BLUE, fill_opacity=0.18
        )
        autoscale(box)
        box.next_to(title, DOWN, buff=1.0)

        targets = VGroup(N_value_line.copy(), Pm_value_line.copy()).arrange(DOWN, buff=0.4)
        targets.move_to(box.get_center()).shift(DOWN*0.1)

        self.play(
            AnimationGroup(
                Create(box),
                N_value_line.animate.move_to(targets[0].get_center()).scale(1.03).set_color(BLUE),
                Pm_value_line.animate.move_to(targets[1].get_center()).scale(1.03).set_color(BLUE),
                lag_ratio=0
            ),
            run_time=1.2
        )
        self.wait(1.2)

        # Titolo box finale
        res_title = GradientTitle("Risultati finali", font_size=36)
        res_title.next_to(box.get_top(), DOWN, buff=0.3)
        self.play(FadeIn(res_title), run_time=0.6)
        self.wait(2.0)
