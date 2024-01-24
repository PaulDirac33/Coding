#!/usr/bin/python3
from PIL import Image
import sys

print('Begin the analysis.\n')

path_in = sys.argv[1]+'/'
path_out = sys.argv[2]+'/'
Imin = int(sys.argv[3])
Imax = int(sys.argv[4])


channel = sys.argv[5]
Dx = float(sys.argv[6])
Dy = float(sys.argv[7])
x_units = sys.argv[8]
y_units = sys.argv[9]
name = 'CH'+channel
variable_name = f'Na_{channel}'
# Na_1 = 217
# Na_2 = 212 
for i in range(Imin, Imax + 1):
    file_name = str(i)

    def find_coordinates(file_in, color):
        image = Image.open(file_in)
        lenght, height = image.size
        coordinates_offset = 0
        coordinates = []
        colors_checked = set()
        offset = 0

        with open('color.txt', 'w+') as file_color:

            for j in range(0,402+1):
                Nc = 0
                
                for x in range(2,23):
                    counts = 0
                    for y in range(47+j,47+15+j):
                        pixel = image.getpixel((x, y))
                        counts += 1
                        if pixel == color:
                            Nc += 1
                        if x == 22 and counts == 8:
                            coordinates_offset = height - y
                #print('j = %i Nc = %i'%(j,Nc))
                if Nc > 210:
                    #print('ciao')
                    offset = coordinates_offset
                    print('Offset '+name+': '+str(offset))
            for x in range(23,lenght):
                for y in range(47,height-30):
                    pixel = image.getpixel((x, y))
                    if pixel not in colors_checked:
                        file_color.write(str(pixel) + '\n')
                        colors_checked.add(pixel)
                    if pixel == color:
                        coordinates.append((x-21, height - y - offset))
        return coordinates

    def save_coordinates(coordinates, file_out):
        with open(file_out, 'w') as file:
            file.write('Time\tV'+ name + '\n')
            file.write(x_units+'\t'+y_units+'\n')
            for coord in coordinates:
                file.write(f"{coord[0]*Dx/50}\t{(coord[1])*Dy/50}\n")

    def main():
        file_input = path_in + file_name + '.bmp'
        color = tuple(map(int, '255 255 0'.split()))      # yellow (CH1)
        #color = tuple(map(int, '0 255 255'.split()))      # light blue (CH2)
        #color = tuple(map(int, '98 101 98'.split()))       # grey (GRID)
        #color = tuple(map(int, '0 170 16'.split()))   # dark green (CURSORS)
        if int(channel) == 1:
            color = tuple(map(int, '255 255 0'.split()))      # yellow (CH1)
        if int(channel) == 2:
            color = tuple(map(int, '0 255 255'.split()))      # light blue (CH2)

        file_output = path_out + name + '_' + file_name + '.dat'

        coordinates_found = find_coordinates(file_input, color)

        if coordinates_found:
            print(f"Target color: {color}\n")
            save_coordinates(coordinates_found, file_output)
            print(f"Color coordinates found and saved on file:\n{file_output}")
        else:
            print(f"Color {color} not found!")

    if __name__ == "__main__":
        main()

