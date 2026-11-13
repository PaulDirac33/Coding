from manim import *
# Variables
logo = "../../LaTeX/logo.png"
textfont = "Times New Roman"
space = 0.2
textsize = 35

# Forziamo formato verticale Instagram 1080x1920
config.frame_width = 9
config.frame_height = 16
config.pixel_width = 1080
config.pixel_height = 1920

class RaftScene(Scene):
    def construct(self):
        # Sfondo nero
        bg = FullScreenRectangle(fill_color=BLACK, fill_opacity=1)
        self.add(bg)

        # Immagine al centro
        BigLogo = ImageMobject(logo)
        BigLogo.scale(1)  # un po' più grande per verticale
        BigLogo.move_to(ORIGIN)

        # Immagine finale in alto
        minyLogo = ImageMobject(logo)
        minyLogo.scale(0.25)
        minyLogo.to_edge(UP, buff=0.1)  # più spazio in verticale

        # Appare al centro
        self.play(FadeIn(BigLogo, run_time=1))
        self.wait(0.25)

        # Cross-fade + movimento
        self.play(FadeTransform(BigLogo, minyLogo, run_time=1))
        self.wait(1)

        # --- AGGIUNTA: Testo titolo sotto il piccolo logo ---
        title_text = Text(
            "LA ZATTERA DI TRONCHI",
            font = textfont,  # carattere spesso
            weight=BOLD,
        )
        title_text.scale(0.9)
        title_text.next_to(minyLogo, DOWN, buff=0.3)  # subito sotto al logo

        # Contorno bianco e interno trasparente bianco
        title_text.set_stroke(WHITE, width=3)
        title_text.set_fill(WHITE, opacity=0.8)  # bianco ma semi-trasparente

        # Animazione di comparsa
        self.play(Write(title_text, run_time=2))
        self.wait(1.5)
        # --- TESTO ESERCIZIO con a capo automatico ---
        textwidth = r"7cm"  # larghezza relativa alla pagina

        intro_text_lines = [
            Tex(rf"\parbox{{{textwidth}}}{{Per raggiungere la terraferma, tre ragazzi di massa:}}", font_size=textsize,tex_environment="flushleft"),
            Tex(rf"\parbox{{{textwidth}}}{{$m_1 = 42.3$ kg, $m_2 = 45.2$ kg e $m_3 = 48.3$ kg}}", font_size=textsize,tex_environment="flushleft"),
            Tex(rf"\parbox{{{textwidth}}}{{costruiscono una zattera con tronchi di quercia.}}", font_size=textsize,tex_environment="flushleft"),
            Tex(rf"\parbox{{{textwidth}}}{{La zattera è formata da tronchi aventi diametro $D = 0.320$ m e lunghezza $L = 1.77$ m,}}", font_size=textsize,tex_environment="flushleft"),
            Tex(rf"\parbox{{{textwidth}}}{{Sapendo che l'acqua ha densità $\rho_1 = 1020$ kg/m$^3$ e che la densità del legno è $\rho_2 = 0.7575$ g/cm$^3$, determinare:}}", font_size=textsize,tex_environment="flushleft"),
            Tex(rf"\parbox{{{textwidth}}}{{\textbf{{a)}} Il numero minimo di tronchi necessari per galleggiare.}}", font_size=textsize,tex_environment="flushleft"),
            Tex(rf"\parbox{{{textwidth}}}{{\textbf{{b)}} La pressione media esercitata dai ragazzi sulla superficie di mezzeria della zattera.}}", font_size=textsize,tex_environment="flushleft"),
        ]

        # Raggruppo, dispongo in colonna e posiziono sotto al titolo
        intro_text = VGroup(*intro_text_lines).arrange(DOWN, aligned_edge=LEFT, buff=space)
        intro_text.next_to(title_text, DOWN, buff=0.8)

        # Centro orizzontalmente il blocco
        #intro_text.set_x(0)

        # Animazioni
        total_time = 39.18
        per_phrase = total_time / len(intro_text_lines)
        for f in intro_text:
            self.play(Write(f), run_time=per_phrase)



