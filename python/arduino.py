#!/opt/homebrew/bin/python3
import serial
import time
import datetime
import json
import threading
import os

stop_keyword = "quit"
stop_event = threading.Event()  # Crea un oggetto Event condiviso
stop_GUI = ''

def user_input_thread():
    user_input = input("\n")
    if user_input.lower() == stop_keyword:
        stop_event.set()  # Imposta l'evento per indicare l'arresto

def GUI_input_thread():
	global stop_GUI
	while not stop_event.is_set():
		txt_file = open('/Users/riccardo/github/Coding/python/GUI/stop.txt', 'r')
		stop_GUI = txt_file.read().strip()

with open('/Users/riccardo/github/Coding/config/arduino.json') as config_file:
    config = json.load(config_file)

File = config['File']
ard = config['Arduino']

current_datetime = datetime.datetime.now()
formatted_datetime = current_datetime.strftime("%Y-%m-%d %H:%M:%S")

path = File["path"]
name = File["name"]
extension = File["extension"]
arduino_port = ard["port_1"]
speed = int(ard["speed"])
sleep = float(ard["sleep"])

if path != '':
	file_out_name = path + '/' + name + '.' + extension
else:
	file_out_name = name + '.' + extension

file = open(file_out_name,'a')
arduino = serial.Serial(arduino_port, speed, timeout=0)
file.write(' -------------------\n')
file.write('|' + formatted_datetime + '|\n')
file.write(' -------------------\n')
arduino.setDTR(False)
time.sleep(0.1)
arduino.flushInput()
arduino.setDTR(True)

user_input_thread = threading.Thread(target=user_input_thread)
user_input_thread.start()
GUI_input_thread = threading.Thread(target=GUI_input_thread)
GUI_input_thread.start()

while not stop_event.is_set():  # Continua fino a quando l'evento non è impostato
    data = arduino.readline()
    if stop_GUI == 'True':
    	file.close()
    	os.system("echo False > stop.txt")
    	os._exit(0)
    if data:
        decoded_data = data.decode().strip()
        print(decoded_data)
        print(stop_GUI)
        file.write(decoded_data + '\n')

    time.sleep(sleep)

user_input_thread.join()
GUI_input_thread.join()
file.close()