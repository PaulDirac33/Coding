#!/opt/homebrew/bin/python3
import serial
import time
import datetime
import json
import threading

stop_keyword = "quit"

def user_input_thread():
    global stop
    user_input = input("\n")
    if user_input.lower() == stop_keyword:
    	stop = True

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


stop = False
user_input_thread = threading.Thread(target=user_input_thread)
user_input_thread.start()

while not stop:
	data = arduino.readline()
	if data:
		decoded_data = data.decode().strip()
		print(decoded_data)
		file.write(decoded_data + '\n')
		
	time.sleep(sleep)
file.close()