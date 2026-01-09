from manim import *

# --- CONFIGURAZIONE GENERALE ---
logo = "../../LaTeX/logo.png"
textfont = "Times New Roman"
space = 0.2
textsize = 35

# Formato verticale (Instagram, TikTok)
config.frame_width = 9
config.frame_height = 16
config.pixel_width = 1080
config.pixel_height = 1920


class ComplexPower(Scene):
    def construct(self):
        # Sfondo nero
        bg = FullScreenRectangle(fill_color=BLACK, fill_opacity=1)
        self.add(bg)

        # Logo principale
        BigLogo = ImageMobject(logo)
        BigLogo.scale(1)
        BigLogo.move_to(ORIGIN)

        # Logo piccolo in alto
        minyLogo = ImageMobject(logo)
        minyLogo.scale(0.25)
        minyLogo.to_edge(UP, buff=0.1)

        # Animazioni logo
        self.play(FadeIn(BigLogo, run_time=1))
        self.wait(0.25)
        self.play(FadeTransform(BigLogo, minyLogo, run_time=1))
        self.wait(1)

        # Titolo
        title_text = Text(
            "LA POTENZA COMPLESSA",
            font=textfont,
            weight=BOLD,
        )
        title_text.scale(0.9)
        title_text.next_to(minyLogo, DOWN, buff=0.3)
        title_text.set_stroke(WHITE, width=3)
        title_text.set_fill(WHITE, opacity=0.8)
        self.play(Write(title_text, run_time=2))
        self.wait(1)

        # --- TESTO ED EQUAZIONI ---
        textwidth = r"7cm"

        intro_text_lines = [
            Tex(rf"\parbox{{{textwidth}}}{{In questo video studiamo i circuiti in regime sinusoidale e, in particolare, il concetto di potenza complessa.}}", font_size=textsize, tex_environment="flushleft"),
            Tex(rf"\parbox{{{textwidth}}}{{Nel regime sinusoidale le grandezze elettriche, tensione e corrente, variano come seni o coseni nel tempo.}}", font_size=textsize, tex_environment="flushleft"),
            Tex(rf"\parbox{{{textwidth}}}{{Per semplificare i calcoli usiamo i fasori, cioè numeri complessi che rappresentano ampiezza e fase dei nostri segnali.}}", font_size=textsize, tex_environment="flushleft"),
            Tex(rf"\parbox{{{textwidth}}}{{La potenza complessa ci permette di collegare in modo semplice i fasori di tensione e corrente al flusso di energia nel circuito.}}", font_size=textsize, tex_environment="flushleft"),
            Tex(rf"\parbox{{{textwidth}}}{{Prima di procedere, ricordiamo brevemente che cosa intendiamo per fasore.}}", font_size=textsize, tex_environment="flushleft"),
        ]
            
        eq1 = Tex(r"$s(t) = A \cos(\omega t + \phi)$", font_size=textsize)
            
        s1_lines = [
            Tex(rf"\parbox{{{textwidth}}}{{Questo segnale può essere interpretato come la parte reale di un numero complesso:}}", font_size=textsize, tex_environment="flushleft"),
        ]

        eq2 = Tex(r"$s(t) = \text{Re}\{A e^{j(\omega t + \phi)}\}$", font_size=textsize)
        s2_lines =[
            Tex(rf"\parbox{{{textwidth}}}{{Separando la parte temporale, possiamo scrivere questo termine come}}", font_size=textsize, tex_environment="flushleft"),
        ]
        eq3 = Tex(r"$A e^{j(\omega t + \phi)} = Ae^{j\phi}e^{j\omega t}$", font_size=textsize)

         # Raggruppo e dispongo
        intro_text = VGroup(*intro_text_lines).arrange(DOWN, aligned_edge=LEFT, buff=space)
        intro_text.next_to(title_text, DOWN, buff=0.8)
        eq1.next_to(intro_text, DOWN, buff=2*space)  # forza centratura orizzontale
        s1 = VGroup(*s1_lines).arrange(DOWN, aligned_edge=LEFT, buff=space)
        s1.next_to(eq1, DOWN, buff=2*space)
        eq2.next_to(s1, DOWN, buff=2*space)
        s2 = VGroup(*s2_lines).arrange(DOWN, aligned_edge=LEFT, buff=space)
        s2.next_to(eq2, DOWN, buff=2*space)
        eq3.next_to(s2, DOWN, buff=2*space)

        # --- Animazioni sequenziali (calcolo dei tempi su tutti gli elementi) ---
        sequence = list(intro_text) + [eq1] + list(s1) + [eq2] + list(s2) + [eq3]
        total_time = 57  # seconds totali (regolali come vuoi)
        per_item = total_time / len(sequence)
        for m in sequence:
            self.play(Write(m), run_time=per_item)

        # --- FINE PRIMA PARTE ---
        self.wait(0.5)

        # Gruppo dei vecchi elementi (esclusa eq3)
        old_group = VGroup(intro_text, eq1, s1, eq2, s2)

        # Faccio salire e dissolvere i vecchi testi
        self.play(
            old_group.animate.shift(UP * 10).set_opacity(0).set_rate_func(smooth),
            eq3.animate.next_to(title_text, DOWN, buff=0.8).set_rate_func(smooth),
            run_time=2
        )


        self.wait(0.5)

        # --- NUOVO TESTO CHE APPARE SOTTO eq3 ---
        second_text_lines = [
            Tex(rf"\parbox{{{textwidth}}}{{Rappresenta quindi un numero complesso di ampiezza $A$, fase iniziale $\phi$,}}", font_size=textsize, tex_environment="flushleft"),
            Tex(rf"\parbox{{{textwidth}}}{{ che ruota nel piano di Gauss con frequenza $\nu = \omega / 2\pi$, in senso antiorario.}}", font_size=textsize, tex_environment="flushleft"),
            Tex(rf"\parbox{{{textwidth}}}{{Possiamo quindi riscrivere il segnale come:}}", font_size=textsize, tex_environment="flushleft"),
        ]
        eq4 = Tex(r"$s_{(t)} = \text{Re}\{\bar{S}e^{j\omega t}\}\qquad \boxed{\bar{S} = Ae^{j\phi}}$", font_size=textsize)
        s3_lines = [
            Tex(rf"\parbox{{{textwidth}}}{{dove $\bar{{S}}$, è detto fasore associato al segnale $s_{{(t)}}$.}}", font_size=textsize, tex_environment="flushleft"),
        ]

    
        second_text = VGroup(*second_text_lines).arrange(DOWN, aligned_edge=LEFT, buff=space)
        second_text.next_to(eq3, DOWN, buff=2*space)
        eq4.next_to(second_text, DOWN, buff=2*space)
        s3 = VGroup(*s3_lines).arrange(DOWN, aligned_edge=LEFT, buff=space)
        s3.next_to(eq4, DOWN, buff=2*space)

        # --- Animazioni sequenziali (calcolo dei tempi su tutti gli elementi) ---
        sequence = list(second_text) + [eq4] + list(s3)
        total_time = 26  # seconds totali (regolali come vuoi)
        per_item = total_time / len(sequence)
        for m in sequence:
            self.play(Write(m), run_time=per_item)

        # --- FINE SECONDA PARTE ---
        # --- TERZA PARTE: Grafico del fasore ---
        import math

        # Creo un piano cartesiano piccolo sotto le formule
        axes = Axes(
            x_range=[-2.5, 2.5, 1],
            y_range=[-2.5, 2.5, 1],
            x_length=4,
            y_length=4,
            axis_config={"color": GRAY_B, "stroke_width": 2},
            tips=True,
        )
        axes.move_to(DOWN * 4)  # sposto in basso

        # Creo il vettore fasore S̄ con φ = 45°
        A = 1.5  # ampiezza del fasore
        phi_deg = 45
        phi = math.radians(phi_deg)
        vector = Arrow(
            start=axes.c2p(0, 0),
            end=axes.c2p(A * math.cos(phi), A * math.sin(phi)),
            buff=0,
            stroke_width=6,
            color=WHITE,
            max_tip_length_to_length_ratio=0.15,
        )

        # Etichetta del vettore
        label = MathTex(r"\bar{S}", font_size=40, color=WHITE)
        label.next_to(vector.get_end(), UP * 0.3 + RIGHT * 0.3)

        # Angolo φ
        arc_phi = Arc(
            radius=0.5,
            start_angle=0,
            angle=phi,
            color=YELLOW,
            stroke_width=4,
        )
        phi_label = MathTex(r"\phi", font_size=35, color=YELLOW)
        phi_label.next_to(arc_phi, RIGHT * 0.4)

        # Aggiungo tutto in scena
        self.play(Create(axes), run_time=1.5)
        self.play(GrowArrow(vector), FadeIn(label), Create(arc_phi), FadeIn(phi_label))
        self.wait(1)

        # Ruotiamo il fasore da 45° → 30° → 0°
        for angle in [30, 0]:
            new_phi = math.radians(angle)
            new_end = axes.c2p(A * math.cos(new_phi), A * math.sin(new_phi))
            self.play(
                vector.animate.put_start_and_end_on(axes.c2p(0, 0), new_end),
                label.animate.next_to(new_end, UP * 0.3 + RIGHT * 0.3),
                arc_phi.animate.become(
                    Arc(radius=0.5, start_angle=0, angle=new_phi, color=YELLOW, stroke_width=4)
                ),
                run_time=1.5,
            )
            self.wait(0.5)

        self.wait(1)


