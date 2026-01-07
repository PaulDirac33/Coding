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

class SphereBuoyancyScene(Scene):
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

        # Titolo
        title_text = Text(
            "LA SFERA IMMERSA",
            font=textfont,
            weight=BOLD,
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
            Tex(rf"\parbox{{{textwidth}}}{{Una sfera di massa $m = 1$ kg e raggio $R = 10$ cm è attaccata ad un filo di lunghezza $L = 1$ m.}}", font_size=textsize, tex_environment="flushleft"),
            Tex(rf"\parbox{{{textwidth}}}{{Il filo è ancorato ad un gancio posto ad una profondità $h = 2$ m,}}", font_size=textsize, tex_environment="flushleft"),
            Tex(rf"\parbox{{{textwidth}}}{{all'interno di una piscina profonda $H = 4$ m.}}", font_size=textsize, tex_environment="flushleft"),
            Tex(rf"\parbox{{{textwidth}}}{{\textbf{{a)}} Confrontare la spinta di Archimede e la forza peso.}}", font_size=textsize, tex_environment="flushleft"),
            Tex(rf"\parbox{{{textwidth}}}{{\textbf{{b)}} In equilibrio statico, a quale profondità si trova la massa?}}", font_size=textsize, tex_environment="flushleft"),
            Tex(rf"\parbox{{{textwidth}}}{{\textbf{{c)}} Calcolare la tensione $T$ del filo.}}", font_size=textsize, tex_environment="flushleft"),
            Tex(rf"\parbox{{{textwidth}}}{{\textbf{{d)}} Spostando la sfera di $\Delta x = 1$ cm orizzontalmente, descrivere il moto e}}", font_size=textsize, tex_environment="flushleft"),
            Tex(rf"\parbox{{{textwidth}}}{{determinare dopo quanto tempo passa per la posizione di equilibrio.}}", font_size=textsize, tex_environment="flushleft"),
        ]

        # Raggruppo e dispongo
        intro_text = VGroup(*intro_text_lines).arrange(DOWN, aligned_edge=LEFT, buff=space)
        intro_text.next_to(title_text, DOWN, buff=0.8)

        # Animazioni sequenziali (~40 s totali)
        total_time = 36
        per_phrase = total_time / len(intro_text_lines)
        for f in intro_text:
            self.play(Write(f), run_time=per_phrase)
