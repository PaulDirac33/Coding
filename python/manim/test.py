from manim import *
import math

# --- CONFIG GENERALE ---
config.frame_width = 9
config.frame_height = 16
config.pixel_width = 1080
config.pixel_height = 1920


class FasoreGraph(Scene):
    def construct(self):
        # Parametri globali (puoi cambiare Cx, Cy per spostare tutto)
        Cx = -1.5        # spostamento orizzontale
        Cy = -2.5     # spostamento verticale

        # Sfondo nero
        bg = FullScreenRectangle(fill_color=BLACK, fill_opacity=1)
        self.add(bg)

        # Piano cartesiano centrato in (Cx, Cy)
               # --- ASSI COME VETTORI PERSONALIZZATI ---
        axis_length = 2.0  # metà lunghezza di ciascun asse

        # Origine degli assi
        origin = np.array([Cx, Cy, 0])

        # Asse X
        x_axis = Arrow(
            start=origin + np.array([-axis_length, 0, 0]),
            end=origin + np.array([axis_length, 0, 0]),
            buff=0,
            stroke_width=3,
            color=GRAY_B,
            tip_shape=ArrowTriangleFilledTip,
            max_tip_length_to_length_ratio=0.05,  # puoi aumentare per punte più grandi
        )

        # Asse Y
        y_axis = Arrow(
            start=origin + np.array([0, -axis_length, 0]),
            end=origin + np.array([0, axis_length, 0]),
            buff=0,
            stroke_width=3,
            color=GRAY_B,
            tip_shape=ArrowTriangleFilledTip,
            max_tip_length_to_length_ratio=0.05,
        )

        # Etichette assi
        # x_label = MathTex("x", color=GRAY_B, font_size=30)
        # y_label = MathTex("y", color=GRAY_B, font_size=30)
        # x_label.next_to(x_axis.get_end(), RIGHT * 0.3)
        # y_label.next_to(y_axis.get_end(), UP * 0.3)

        # Disegna gli assi
        self.play(GrowArrow(x_axis), GrowArrow(y_axis), run_time=1)

            # Funzione per convertire coordinate (x, y) in punti nella scena
        def c2p(x, y):
            return origin + np.array([x, y, 0])


        # Parametri del fasore
        A = 1.5
        phi_deg = 45
        phi = math.radians(phi_deg)

        # Fasore S̄ (freccia in stile "stealth")
        end = c2p(A * math.cos(phi), A * math.sin(phi))
        vector = Arrow(
            start=origin,
            end=end,
            buff=0,
            stroke_width=6,
            color=WHITE,
            tip_shape=ArrowTriangleFilledTip,
            max_tip_length_to_length_ratio=0.15,
        )

        # Etichetta fasore
        label = MathTex(r"\bar{S}", font_size=40, color=WHITE)
        label.next_to(end, UP * 0.3 + RIGHT * 0.3)

        # Arco φ
        arc_radius = 0.6
        arc_phi = Arc(
            radius=arc_radius,
            start_angle=0,
            angle=phi,
            color=YELLOW,
            stroke_width=4,
        ).shift(origin)

        phi_label = MathTex(r"\phi", font_size=35, color=YELLOW)
        phi_label.move_to(
            origin
            + 1.5 * arc_radius * np.array(
                [math.cos(phi / 2), math.sin(phi / 2), 0]
            )
        )

        self.play(GrowArrow(vector), FadeIn(label), Create(arc_phi), FadeIn(phi_label))
        self.wait(1)

        # # Cerchio di raggio A (centrato nell'origine)
        # circle = Circle(
        #     radius=A,
        #     color=GRAY_B,
        #     stroke_width=2,
        # ).shift(origin)

        # self.play(Create(circle), run_time=1)

        # Rotazione del fasore: vettore, arco e etichette si muovono insieme (sincrono)
        for angle in [90, 30, 0]:
            new_phi = math.radians(angle)
            delta = new_phi - phi  # angolo di rotazione relativo

            # Calcola le posizioni di destinazione basate sul nuovo angolo
            new_end = origin + np.array([A * math.cos(new_phi), A * math.sin(new_phi), 0])
            new_arc = Arc(
                radius=arc_radius,
                start_angle=0,
                angle=new_phi,
                color=YELLOW,
                stroke_width=4,
            ).shift(origin)
            new_phi_label_pos = origin + 1.5 * arc_radius * np.array(
                [math.cos(new_phi / 2), math.sin(new_phi / 2), 0]
            )

            # Esegui TUTTO in una singola play: il vettore ruota, l'arco si trasforma,
            # la label del fasore e la label phi si spostano fluentemente insieme.
            self.play(
                Rotate(vector, angle=delta, about_point=origin),
                Transform(arc_phi, new_arc),
                label.animate.move_to(new_end + (UP * 0.3 + RIGHT * 0.3)),
                phi_label.animate.move_to(new_phi_label_pos),
                run_time=1.5,
            )

            # aggiorna phi per il prossimo step
            phi = new_phi
            self.wait(0.3)
        # Dissolvenza dell'arco e dell'etichetta φ
        self.play(
            FadeOut(arc_phi),
            FadeOut(phi_label),
            run_time=1
        )
        self.wait(0.5)


                # Riduzione dell'ampiezza del fasore da A=1.5 a A=1.0
        new_A = 1.0
        new_end = c2p(new_A * math.cos(new_phi), new_A * math.sin(new_phi))

        self.play(
            vector.animate.put_start_and_end_on(origin, new_end),
            label.animate.next_to(new_end, UP * 0.3 + RIGHT * 0.3),
            run_time=1.5,
        )
        self.wait(1)
        
