#!/usr/bin/python3

from kivy.app import App
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.button import Button
from kivy.uix.label import Label
from kivy.uix.textinput import TextInput
from kivy.uix.widget import Widget
from kivy.graphics import Color, Rectangle
from kivy.core.window import Window
from kivy.uix.gridlayout import GridLayout
import json

Window.size = (550,780)
class T_extraction(App):
    def build(self):
        self.layout = BoxLayout(orientation='vertical')

        self.title_label = Label(text="T_extraction.py", height=50, bold=True, font_size=50, color=(0, 0.5, 1, 0.8))
        self.layout.add_widget(self.title_label)
        self.data = self.load_json_data("/Users/riccardo/github/Coding/config/T_extraction.json")
        self.text_inputs = {}
        Window.clearcolor = (0.1, 0.1, 0.1, 1)  # Imposta il colore di sfondo
        
        for section_name, section_data in self.data.items():
            section_label = Label(text=section_name, bold=True, font_size=40, color=(1, 1, 1, 0.8))
            self.layout.add_widget(section_label)
            
            section_layout = GridLayout(cols=2)
            self.layout.add_widget(section_layout)
            
            for key, value in section_data.items():
                label = Label(text=key, bold=True, font_size=30, color=(0, 0.5, 1, 0.8))
                text_input = TextInput(text=value, multiline=False, font_size=20,height=35,size_hint_y=None)
                
                self.text_inputs[key] = text_input
                
                section_layout.add_widget(label)
                section_layout.add_widget(text_input)

        spacer = Widget(size_hint_y=None, height=200)

        self.layout.add_widget(spacer)
        button_layout = BoxLayout(orientation='horizontal', size_hint_y=None, height=80)
        button_save = Button(text="SAVE", bold=True, font_size=40, size_hint=(None, None), size=(150, 60), color=(1, 1, 1, 0.8))
        button_save.background_color = (0, 0.5, 1, 1)
        button_save.bind(on_press=self.save_json)
        button_save.pos_hint = {'center_x': 0.35}
        self.layout.add_widget(button_save)

        button_run = Button(text="RUN", bold=True, font_size=40, size_hint=(None, None), size=(150, 60), color=(1, 1, 1, 0.8))
        button_run.background_color = (0, 0.5, 1, 1)
        button_run.bind(on_press=self.run_code)  # Collegato a una nuova funzione "run_code"
        button_run.pos_hint = {'center_x': 0.65}
        self.layout.add_widget(button_run)

        self.layout.add_widget(button_layout)

        self.result_label = Label(text="", size_hint_y=None, height=40)
        self.layout.add_widget(self.result_label)
        return self.layout


    
    def load_json_data(self, filename):
        with open(filename, 'r') as f:
            data = json.load(f)
        return data
    def run_code(self, instance):
        print("Hello world")
    
    def save_json(self, instance):
        for key, text_input in self.text_inputs.items():
            value = text_input.text
            for section_data in self.data.values():
                if key in section_data:
                    section_data[key] = value
        
        try:
            with open('/Users/riccardo/github/Coding/config/T_extraction.json', 'w') as outfile:
                json.dump(self.data, outfile, indent=2)
            self.result_label.text = "JSON saved successfully!"
        except Exception as e:
            self.result_label.text = f"Error: {e}"

if __name__ == '__main__':
    T_extraction().run()