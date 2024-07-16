#!/bin/bash

# Directory corrente
watch_directory=$(pwd)

# Funzione per ottenere il timestamp dell'ultima modifica del file
get_file_mod_time() {
    if [ -e "$1" ]; then
        stat -f %m "$1"
    else
        echo 0
    fi
}

# Funzione per monitorare e cancellare i file
delete_temp_files() {
    local dir=$1
    local files_deleted=false
    # Trova i file con le estensioni specificate
    for file in "$dir"/*.{aux,fdb_latexmk,fls,log,out,synctex.gz,toc}; do
        if [ -e "$file" ]; then
            rm -f "$file"
            echo "Cancellato $file"
            files_deleted=true
        fi
    done
    if [ "$files_deleted" = false ]; then
        echo "Nessun file temporaneo trovato da cancellare."
    fi
}

# Array per memorizzare i file PDF e i loro timestamp di modifica
pdf_files=()
pdf_mod_times=()

# Ottieni la lista dei file PDF iniziali e i loro timestamp di modifica
for pdf in "$watch_directory"/*.pdf; do
    pdf_files+=("$pdf")
    pdf_mod_times+=("$(get_file_mod_time "$pdf")")
done

# Loop principale per monitorare le modifiche ai file PDF
while true; do
    for i in "${!pdf_files[@]}"; do
        pdf="${pdf_files[$i]}"
        if [ -e "$pdf" ]; then
            current_mod_time=$(get_file_mod_time "$pdf")
            if [ "$current_mod_time" -ne "${pdf_mod_times[$i]}" ]; then
                echo "$pdf modificato. Attendo 6 secondi prima di cancellare i file..."
                sleep 6
                delete_temp_files "$watch_directory"
                pdf_mod_times[$i]=$current_mod_time
            fi
        fi
    done

    # Aggiungi nuovi file PDF trovati nella directory
    for new_pdf in "$watch_directory"/*.pdf; do
        found=false
        for existing_pdf in "${pdf_files[@]}"; do
            if [ "$new_pdf" == "$existing_pdf" ]; then
                found=true
                break
            fi
        done
        if ! $found; then
            pdf_files+=("$new_pdf")
            pdf_mod_times+=("$(get_file_mod_time "$new_pdf")")
        fi
    done

    # Attendere prima di controllare nuovamente
    sleep 5  # Aumentato il tempo di attesa per ridurre l'uso delle risorse
done
