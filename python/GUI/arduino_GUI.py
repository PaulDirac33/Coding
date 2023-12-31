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
import os
import subprocess
import time

a = 1 # Scale, let 1 for 1920x1080 thus set 2 for 2560x1600

Window.size = (455,660)
class Arduino(App):
    def build(self):
        self.layout = BoxLayout(orientation='vertical')

        self.title_label = Label(text="Arduino acquisition", height=a*50, bold=True, font_size=a*50, color=(0, 0.5, 1, 0.8))
        self.layout.add_widget(self.title_label)
        self.data = self.load_json_data("/Users/riccardo/github/Coding/config/arduino.json")
        self.text_inputs = {}
        Window.clearcolor = (0.1, 0.1, 0.1, 1)
        
        for section_name, section_data in self.data.items():
            section_label = Label(text=section_name, bold=True, font_size=a*40, color=(1, 1, 1, 0.8))
            self.layout.add_widget(section_label)
            
            section_layout = GridLayout(cols=2)
            self.layout.add_widget(section_layout)
            
            for key, value in section_data.items():
                label = Label(text=key, bold=True, font_size=a*30, color=(0, 0.5, 1, 0.8))
                text_input = TextInput(text=value, multiline=False, font_size=a*20,height=a*35,size_hint_y=None)
                
                self.text_inputs[key] = text_input
                
                section_layout.add_widget(label)
                section_layout.add_widget(text_input)

        spacer = Widget(size_hint_y=None, height=a*70)

        self.layout.add_widget(spacer)
        button_layout = BoxLayout(orientation='horizontal', size_hint_y=None, height=80)
        button_save = Button(text="SAVE", bold=True, font_size=a*40, size_hint=(None, None), size=(a*150, a*60), color=(1, 1, 1, 0.8))
        button_save.background_color = (0, 0.5, 1, 1)
        button_save.bind(on_press=self.save_json)
        button_save.pos_hint = {'center_x': 0}
        button_layout.add_widget(button_save)

        self.run_button_original_color = (0, 0.5, 1, 1)
        self.stop_button_original_color = (0, 0.5, 1, 1)

        button_run = Button(text="RUN", bold=True, font_size=a*40, size_hint=(None, None), size=(a*150, a*60), color=(1, 1, 1, 0.8))
        button_run.background_color = (0, 0.5, 1, 1)
        button_run.bind(on_press=self.run_code)
        button_run.bind(on_release=self.reset_color)
        button_run.pos_hint = {'center_x': 0.5}
        button_layout.add_widget(button_run)

        button_stop = Button(text="STOP", bold=True, font_size=a*40, size_hint=(None, None), size=(a*150, a*60), color=(1, 1, 1, 0.8))
        button_stop.background_color = (0, 0.5, 1, 1)
        button_stop.bind(on_press=self.stop_code)
        button_stop.bind(on_release=self.reset_color)
        button_stop.pos_hint = {'center_x': 1}
        button_layout.add_widget(button_stop)

        self.layout.add_widget(button_layout)

        self.result_label = Label(text="", size_hint_y=None, height=40)
        self.layout.add_widget(self.result_label)
        return self.layout
        
    def load_json_data(self, filename):
        with open(filename, 'r') as f:
            data = json.load(f)
        return data
    def run_code(self, instance):
        instance.background_color = (0, 1, 0, 0.5)
        self.arduino_process = subprocess.Popen(["python3", "../arduino.py"])
        self.result_label.text = "Running..."
    def stop_code(self, instance):
        instance.background_color = (1, 0, 0, 1)
        os.system("echo True > stop.txt")
        print('\n####################')
        self.result_label.text = "Program stopped!"
    
    def save_json(self, instance):
        for key, text_input in self.text_inputs.items():
            value = text_input.text
            for section_data in self.data.values():
                if key in section_data:
                    section_data[key] = value
        try:
            with open('/Users/riccardo/github/Coding/config/arduino.json', 'w') as outfile:
                json.dump(self.data, outfile, indent=2)
            self.result_label.text = "JSON saved successfully!"
        except Exception as e:
            self.result_label.text = f"Error: {e}"
    def reset_color(self, instance):
        if instance.text == "RUN":
            instance.background_color = self.run_button_original_color
        elif instance.text == "STOP":
            instance.background_color = self.stop_button_original_color

if __name__ == '__main__':
    Arduino().run()