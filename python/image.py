#!/usr/bin/python3
from PIL import Image

def trova_coordinate_immagine(nome_file, colore_ricerca):
    immagine = Image.open(nome_file)
    larghezza, altezza = immagine.size
    coordinate = []

    for x in range(larghezza):
        for y in range(altezza):
            pixel = immagine.getpixel((x, y))
            print(pixel)
            if pixel == colore_ricerca:
                coordinate.append((x, altezza - y))

    return coordinate

def salva_coordinate_su_file(coordinate, nome_file_output):
    with open(nome_file_output, 'w') as file:
        for coord in coordinate:
            file.write(f"{coord[0]}\t{coord[1]}\n")

def main():
    nome_file = '/Users/riccardo/github/Coding/images/17.bmp'
    colore_ricerca = tuple(map(int, '74 77 74 255 '.split()))
    nome_file_output = 'image.txt'

    coordinate_trovate = trova_coordinate_immagine(nome_file, colore_ricerca)

    if coordinate_trovate:
        print(f"Coordinate del colore {colore_ricerca}:")
        for coord in coordinate_trovate:
            print(coord)
        
        salva_coordinate_su_file(coordinate_trovate, nome_file_output)
        print(f"Le coordinate sono state salvate nel file {nome_file_output}.")
    else:
        print(f"Nessuna coordinata trovata per il colore {colore_ricerca}.")

if __name__ == "__main__":
    main()

