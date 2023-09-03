#!/usr/bin/python3
import math
import time

N = int(input("Insert N: "))
an = 0.0
an_prev = 0.0

with open("series.dat", "w") as file:
    file.write("n\tΣ(1/n^2)\n")

    tic = time.time()
    
    for n in range(1, N + 1):
        an += math.pow(n, -2)
        file.write(f"{n}\t{an:.9f}\n")
        
        if n > 1 and abs(an_prev - an) <= math.pow(10, -9):
            break
        
        an_prev = an
    
    toc = time.time()
    duration = toc - tic
    Time = duration * 1000
    
    print(f"Tempo impiegato: %i ms"%Time)