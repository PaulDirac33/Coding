from manim import *

# Variabili
logo = "../../LaTeX/logo.png"
textfont = "Times New Roman"
space = 0.2
textsize = 35

# Formato verticale Instagram 1080x1920
config.frame_width = 9
config.frame_height = 16
config.pixel_width = 1080
config.pixel_height = 1920

class ElectronScene(Scene):
    def construct(self):
        # Sfondo nero
        bg = FullScreenRectangle(fill_color=BLACK, fill_opacity=1)
        self.add(bg)

        # Logo al centro
        BigLogo = ImageMobject(logo)
        BigLogo.scale(1)
        BigLogo.move_to(ORIGIN)

        # Logo finale in alto
        minyLogo = ImageMobject(logo)
        minyLogo.scale(0.25)
        minyLogo.to_edge(UP, buff=0.1)

        # Intro logo
        self.play(FadeIn(BigLogo, run_time=1))
        self.wait(0.25)
        self.play(FadeTransform(BigLogo, minyLogo, run_time=1))
        self.wait(1)

        # Titolo con LaTeX
        title_text = Tex(
            r"\textbf{L' ELETTRONE} $\boldsymbol{\left|1s\right>}$",
            font_size=65  # controlli la dimensione
        )

        title_text.scale(0.8)
        title_text.next_to(minyLogo, DOWN, buff=0.3)
        title_text.set_stroke(WHITE, width=3)
        title_text.set_fill(WHITE, opacity=0.8)
        self.play(Write(title_text, run_time=2))
        self.wait(1.5)

        # Testo esercizio
        textwidth = r"7cm"

        intro_text_lines = [
            Tex(rf"\parbox{{{textwidth}}}{{Lo stato fondamentale dell'eletrone nell'atomo di idrogeno è indicato con $\left|1s\right>$.}}", font_size=textsize, tex_environment="flushleft"),
            Tex(rf"\parbox{{{textwidth}}}{{In questo stato quantico l'elettrone ha un energia di $-13.6$ eV, ma non ha una posizione ben definita.}}", font_size=textsize, tex_environment="flushleft"),
            Tex(rf"\parbox{{{textwidth}}}{{La sua funzione d'onda è data dalla seguente formula:}}", font_size=textsize, tex_environment="flushleft"),
        ]
        # Equazione centrata
        equation = Tex(rf"\parbox{{{textwidth}}}{{$$\psi_{{1s(x)}} = \frac{1}{{\sqrt{{\pi a_0^3}}}}e^{{-\frac{{r}}{{a_0}}}}$$}}", font_size=1.25*textsize)
        extra_text_lines = [
            Tex(rf"\parbox{{{textwidth}}}{{Dove $a_0=0.529$ \AA\space è il raggio di Bohr.}}", font_size=textsize, tex_environment="flushleft"),
            Tex(rf"\parbox{{{textwidth}}}{{\textbf{{a)}} Calcolare la probabilità che l'elettrone si trovi in un guscio sferico di spessore $s = 1$ pm, centrato in $a_0$. Per il calcolo numerico approssimare in termini di $s/a_0$}}", font_size=textsize, tex_environment="flushleft"),
        ]

        # Raggruppo e dispongo
        intro_text = VGroup(*intro_text_lines).arrange(DOWN, aligned_edge=LEFT, buff=space)
        intro_text.next_to(title_text, DOWN, buff=0.8)
        equation.next_to(intro_text, DOWN, buff=space)  # forza centratura orizzontale
        extra_text = VGroup(*extra_text_lines).arrange(DOWN, aligned_edge=LEFT, buff=space)
        extra_text.next_to(equation, DOWN, buff=0.5)

        # --- Animazioni sequenziali (calcolo dei tempi su tutti gli elementi) ---
        sequence = list(intro_text) + [equation] + list(extra_text)
        total_time = 36  # seconds totali (regolali come vuoi)
        per_item = total_time / len(sequence)
        for m in sequence:
            self.play(Write(m), run_time=per_item)
