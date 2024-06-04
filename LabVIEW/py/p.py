#!/usr/bin/python3
import serial
port = '/dev/cu.usbmodem21301'
baudrate = 115200
a = 0
b = 0
def start_serial_comm(port, baudrate):
	ser = serial.Serial(port, baudrate)
	setup = "Start communicatione on serial port: " + port + " at: " + "%i baud"%baudrate
	return setup