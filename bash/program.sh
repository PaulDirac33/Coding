#!/bin/bash
echo "Inserire il percorso dei file da unire:"
read path_in
echo
echo "Inserire il percorso del file in output:"
read path_out
echo
echo "Inserire il tipo dell'array:"
read array
echo 

for file in "$path_in/""$array"*; do
    cat "$file" >> "$path_out/""$array".txt
done
echo 
echo "Unione completata con successo!"
echo 
echo "Inizio ad estrarre la supercorrente"
echo 

./python/Ic_extraction.py $path_out $array

echo 
echo "Ramo supercorrente estratto!"
echo 
echo "Calcolo la distribuzione di probabilità"
echo 

./python/pdf_extraction.py $path_out

echo 
echo "Distribuzione di probabilità calcolata!"
echo 
echo "Inizio a generare le correnti simulate"
echo 

if [ "$array" == "BB" ]; then
    echo "Calcolo la supercorrente del BB"
    echo "Si vogliono generare entrambe le funzioni?"
    read quanti
    echo

    ./python/simulation.py $path_out $array $quanti
    
    echo 
    echo "Corrente generata"
    echo 
    echo "Calcolo la distribuzione di probabilità"
    echo 
    if [ "$quanti" == "no" ]; then
        ./python/pdf_extraction.py $path_out
    else
        ./python/pdf_extraction.py $path_out
        echo
        echo "Calcolo la seconda distribuzione"
        ./python/pdf_extraction.py $path_out 
    fi  
    echo 
    echo "Distribuzione di probabilità calcolata!"
elif [ "$array" == "Ref" ]; then
    echo "Calcolo la supercorrente del Ref"
    echo "Si vogliono generare entrambe le funzioni?"
    read quanti
    echo 

    ./python/simulation.py $path_out $array $quanti
    
    echo 
    echo "Corrente generata"
    echo 
    echo "Calcolo la distribuzione di probabilità"
    echo 
    if [ "$quanti" == "no" ]; then
        ./python/pdf_extraction.py $path_out
    else
        ./python/pdf_extraction.py $path_out
        echo
        echo "Calcolo la seconda distribuzione"
        ./python/pdf_extraction.py $path_out 
    fi
    echo  
    echo "Distribuzione di probabilità calcolata!"
fi