#!/usr/bin/python3

#----------------------------------------------------------------------------#
# LIBRARIES

from PIL import Image

#----------------------------------------------------------------------------#
# VARIABLES

t = 46
b = 30
r = 73
fx = 20
fy = 15
pixel_time = 63
channel = 1
Dx = 2.5
Dy = 1
x_units = 'V'
y_units = 'V'
current_mode = 0
R = 11.9
R_units = 'Ω'

name = 'CH'+channel
variable_name = f'Na_{channel}'

#----------------------------------------------------------------------------#
# FUNCTIONS

def find_coordinates(file_in, color):
        image = Image.open(file_in)
        lenght, height = image.size
        coordinates_offset = 0
        coordinates = []
        colors_checked = set()
        offset = 0
        #print(lenght)
        #print(height)
        with open('color.txt', 'w+') as file_color:
            for j in range(0, height -(t+2+fy)):
                Nc = 0              
                for x in range(2,2+fx):
                    counts = 0
                    for y in range(-1+t+2+j,t+2+fy+j):
                        pixel = image.getpixel((x, y))
                        counts += 1
                        if pixel == color:
                            Nc += 1
                        if x == fx + 1 and counts == 8:
                            coordinates_offset = height - y
                #print('j = %i Nc = %i'%(j,Nc))
                if Nc > 210:
                    print(Nc)
                    offset = coordinates_offset
                    print('Offset '+name+': '+str(offset))
            for x in range(-1+4,lenght-r-1):
                if image.getpixel((x,pixel_time)) == tuple(map(int, '0 255 0'.split())):
                    zero = x
    return(zero, offset)



