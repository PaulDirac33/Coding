from manim import *

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
        BigLogo = ImageMobject("../../LaTeX/logo.png")
        BigLogo.scale(1)  # un po' più grande per verticale
        BigLogo.move_to(ORIGIN)

        # Immagine finale in alto
        minyLogo = ImageMobject("../../LaTeX/logo.png")
        minyLogo.scale(0.25)
        minyLogo.to_edge(UP, buff=0.1)  # più spazio in verticale

        # Appare al centro
        self.play(FadeIn(BigLogo, run_time=1))
        self.wait(0.5)

        # Cross-fade + movimento
        self.play(FadeTransform(BigLogo, minyLogo, run_time=1.25))
        self.wait(1.25)

        # --- AGGIUNTA: Testo titolo sotto il piccolo logo ---
        title_text = Text(
            "LA ZATTERA DI TRONCHI",
            font="Times New Roman",  # carattere spesso
            weight=BOLD,
        )
        title_text.scale(0.9)
        title_text.next_to(minyLogo, DOWN, buff=0.3)  # subito sotto al logo

        # Contorno bianco e interno trasparente bianco
        title_text.set_stroke(WHITE, width=3)
        title_text.set_fill(WHITE, opacity=0.6)  # bianco ma semi-trasparente

        # Animazione di comparsa
        self.play(Write(title_text, run_time=1.5))
        self.wait(1.5)
        # --- TESTO ESERCIZIO ---
        intro_text = Tex(
            r"\parbox{0.8\textwidth}{Per raggiungere la terraferma, tre ragazzi di massa "
            r"$m_1 = 42.3$ kg, $m_2 = 45.2$ kg e  $m_3 = 48.3$ kg, "
            r"costruiscono una zattera con tronchi di quercia. "
            r"La zattera è formata da tronchi aventi diametro "
            r"$D = 0.320$ m e lunghezza $L = 1.77$ m. "
            r"Sapendo che l'acqua ha densità "
            r"$\rho_1 = 1020$ kg/m$^3$ "
            r"e che la densità del legno è "
            r"$\rho_2 = 0.7575$ g/cm$^3$, "
            r"determinare:}",
            font_size=28,
            tex_environment="flushleft",
        )
        request_a = Tex(
            r"\parbox{0.8\textwidth}{\textbf{a)} Il numero minimo di tronchi necessari per galleggiare.}",
            font_size=28,
            tex_environment="flushleft",
        )
        request_b = Tex(
            r"\parbox{0.8\textwidth}{\textbf{b)} La pressione media esercitata dai ragazzi sulla superficie di mezzeria della zattera.}",
            font_size=28,
            tex_environment="flushleft",
        )

        # Posizionamento sotto il titolo
        intro_text.next_to(title_text, DOWN, buff=0.8)
        request_a.next_to(intro_text, DOWN, aligned_edge=LEFT, buff=0.4)
        request_b.next_to(request_a, DOWN, aligned_edge=LEFT, buff=0.2)

        # Animazioni separate (tempo diverso per ognuna)
        self.play(Write(intro_text, run_time=34))   # più lungo
        self.play(Write(request_a, run_time=2))    # medio
        self.play(Write(request_b, run_time=2))    # medio

        # --- SEZIONE DATI ---
        self.wait(1)
        dati_title = Tex(r"\textbf{Dati}", font_size=36)
        dati_title.next_to(request_b, DOWN, buff=0.5).to_edge(LEFT)

        # Scrittura normale dei dati
        m1_tex = Tex(r"$m_1 = 42.3\ \mathrm{kg}$", font_size=28)
        m2_tex = Tex(r"$m_2 = 45.2\ \mathrm{kg}$", font_size=28)
        m3_tex = Tex(r"$m_3 = 48.3\ \mathrm{kg}$", font_size=28)
        D_tex  = Tex(r"$D = 0.320\ \mathrm{m}$", font_size=28)
        L_tex  = Tex(r"$L = 1.77\ \mathrm{m}$", font_size=28)
        rho1_tex = Tex(r"$\rho_1 = 1020\ \mathrm{kg/m}^3$", font_size=28)
        rho2_tex = Tex(r"$\rho_2 = 0.7575\ \mathrm{g/cm}^3$", font_size=28)

        dati_group = VGroup(
            m1_tex, m2_tex, m3_tex, D_tex, L_tex, rho1_tex, rho2_tex
        ).arrange(DOWN, aligned_edge=LEFT, buff=0.3).next_to(dati_title, DOWN, aligned_edge=LEFT, buff=0.3)

        # Brace a destra delle masse
        brace = Brace(VGroup(m1_tex, m2_tex, m3_tex), RIGHT, buff=0.2)
        M_tex = Tex(r"$M = m_1 + m_2 + m_3 = 135.8\ \mathrm{kg}$", font_size=28)
        M_tex.next_to(brace, RIGHT, buff=0.3)

        # Conversione di rho2 (aggiunta a destra)
        rho2_conv = Tex(r"$= 757.5\ \mathrm{kg/m}^3$", font_size=28)
        rho2_conv.next_to(rho2_tex, RIGHT, buff=0.1)

        # --- Animazioni ---
        self.play(Write(dati_title))
        self.play(LaggedStart(*[Write(obj) for obj in dati_group], lag_ratio=0.25, run_time=4))

        # Appare la parentesi graffa e M
        self.play(Create(brace), run_time=0.75)
        self.wait(0.25)
        self.play(Write(M_tex), run_time=1)
        self.wait(0.25)
        # Conversione di rho2 (a destra sulla stessa linea)
        self.play(Write(rho2_conv), run_time=1.5)

        



