#!/bin/bash

# We must be in /Users/.../MOSFET/bash

#                             MOSFET
#                               |
#                 ______________v_____________        
#                |                            |
#    ____________v____________              *.png
#   |            |            |
#  bash       gnuplot        data
#   |            |            |
#  *.sh         *.gp       *.dat
#---------------------------------------------------------------------------------------------
setup_file="../gnuplot/setup.md"                                          # path of setup file
#---------------------------------------------------------------------------------------------
echo "############################################"
echo "Insert the prefix of input files (default .dat):"
read prefix
echo "Insert the prefix of output files( default .png/.gp):"
read file_out
echo "Insert title:"
read title
#---------------------------------------------------------------------------------------------
data_dir=$(grep data_path "$setup_file" | awk '{print $4}')     # import input files directory
script_dir=$(grep script_path "$setup_file" | awk '{print $4}') # import output file directory
images_dir=$(grep images_path "$setup_file" | awk '{print $4}')      # import images directory
colors_file=$(grep color_path "$setup_file" | awk '{print $4}')                # import colors
logscale_y=$(grep logscale_y "$setup_file" | awk '{print $4}')             # import axis scale
logscale_x=$(grep logscale_x "$setup_file" | awk '{print $4}')
xy=$(grep x:y "$setup_file" | awk '{for (i=4; i<=NF; i++) print $i}')
pt=$(grep point_type "$setup_file" | awk '{print $4}')                    # import points type
ps=$(grep point_size "$setup_file" | awk '{print $4}')                    # import points size 
lt=$(grep line_type "$setup_file" | awk '{print $4}')                    # import points type
ls=$(grep line_size "$setup_file" | awk '{print $4}')
image_size=$(grep image_size "$setup_file" | awk '{for (i=4; i<=NF; i++) print $i}')
font=$(grep font "$setup_file" | awk '{for (i=4; i<=NF; i++) print $i}')         # import font
size=$(grep text_size "$setup_file" | awk '{print $4}')
xl_off=$(grep x_label_offset "$setup_file" | awk '{for (i=4; i<=NF; i++) print $i}')  # offets
xt_off=$(grep x_tics_offset "$setup_file" | awk '{for (i=4; i<=NF; i++) print $i}')
yl_off=$(grep y_label_offset "$setup_file" | awk '{for (i=4; i<=NF; i++) print $i}')
yt_off=$(grep y_tics_offset "$setup_file" | awk '{for (i=4; i<=NF; i++) print $i}')
samples=$(grep samples "$setup_file" | awk '{print $4}')
l=$(grep lmargin "$setup_file" | awk '{print $4}')
b=$(grep bmargin "$setup_file" | awk '{print $4}')
r=$(grep rmargin "$setup_file" | awk '{print $4}')
#---------------------------------------------------------------------------------------------
input_files=($(ls "$data_dir"/"$prefix"*.dat))                            # import input files
number_files=${#input_files[@]}                                     # number of imported files                                              
output_file=$images_dir"/"$file_out".png"                          # relative path of file_out
gnuplot_script_png="$script_dir""/png.gp"            # relative path of gnuplot script for the image
gnuplot_script="$script_dir""/"$file_out".gp"  # relative path of gnuplot script for the graph
#---------------------------------------------------------------------------------------------
names=()                                                                             # name of physical quantities
x_names=()
y_names=()
units=()                                                                    # units of measure
x_units=()
y_units=()
comments=()                                                                         # comments
echo "Importing files"
echo
for ((i=0; i<number_files; i++)); do
  name=$(head -1 "${input_files[i]}")
  names+=("$name")

  x_name=$(echo "$name" | awk '{print $1}')
  x_names+=("$x_name")
  y_name=$(echo "$name" | awk '{print $2}')
  y_names+=("$y_name")

  unit=$(sed -n '3p' "${input_files[i]}")
  units+=("$unit")
  x_unit=$(echo "$unit" | awk '{print $1}')
  x_units+=("$x_unit")
  y_unit=$(echo "$unit" | awk '{print $2}')
  y_units+=("$y_unit")

  comment=$(sed -n '2p' "${input_files[i]}")
  comments+=("$comment")
  echo "$((i+1))) "${input_files[i]}""
done
#-------------------------------------------------------------------------------------------
# Logarithmic fit for MOSFET 
Vgs=()
A=()
B=()
fun=()
for ((i=0; i<number_files; i++)); do
    Vgs+=($(echo "${comments[i]}" | awk '{print $3}'))
    A+=($(echo $(grep "${Vgs[i]}" "$data_dir/param.txt") | awk '{print $2}'))
    B+=($(echo $(grep "${Vgs[i]}" "$data_dir/param.txt") | awk '{print $3}'))
    fun+=("${A[i]}"'*log('"${B[i]}"'*x)')
done

colors=()
for ((i=1; i<=number_files; i++)); do
    rgb=$(head -$i "$colors_file" | tail -1 | awk '{print $3}')
    colors+=("$rgb")
done                
#-------------------------------------------------------------------------------------------            
title="set title '"$title"' font '"$font","$size"'"

echo $title > "$gnuplot_script_png"
echo $title > "$gnuplot_script"

Xaxis="set xlabel '"$x_name" ("$x_unit")' font '$font,"$size"'\n
       set xlabel offset "$xl_off"\n
       set xtics font '"$font","$size"'\n
       set xtics offset "$xt_off""

if [ "$logscale_x" == 'yes' ] || [ "$logscale_x" == 'y' ]; then
  Xaxis="$Xaxis""\n set logscale x"
else
  Xaxis="$Xaxis""\n unset logscale x"
fi

echo -e $Xaxis >> "$gnuplot_script_png"
echo -e $Xaxis >> "$gnuplot_script"

Yaxis="set ylabel '"$y_name" ("$y_unit")' font '$font,"$size"'\n
         set ylabel offset "$yl_off"\n
       set ytics font '"$font","$size"'\n
       set ytics offset "$yt_off""

if [ "$logscale_y" == 'yes' ] || [ "$logscale_y" == 'y' ]; then
  Yaxis="$Yaxis""\n set logscale y"
else
  Yaxis="$Yaxis""\n unset logscale y"
fi

echo -e $Yaxis >> "$gnuplot_script_png"
echo -e $Yaxis >> "$gnuplot_script"

echo "set key font '"$font","$size"'" >> "$gnuplot_script_png"
echo "set key font '"$font","$size"'" >> "$gnuplot_script"

echo -e "set terminal pngcairo enhanced size $image_size\n
             set output '"$output_file"'" >> "$gnuplot_script_png"

sample_margin="set samples "$samples"\n
                     set lmargin "$l"\n
                     set bmargin "$b"\n
                     set rmargin "$r"\n"

echo -e $sample_margin >> "$gnuplot_script_png"
echo -e $sample_margin >> "$gnuplot_script"

if [ "$number_files" -eq 1 ]; then
  plot="plot '"${input_files[0]}"' using "$xy" with points title '"${comments[0]}"' lc rgb '"${colors[0]}"' pt "$pt" ps "$ps", \
        "${fun[0]}" with lines title '' lc rgb 'black' dt '"$lt"' lw "$ls""
else 
  plot="plot '"${input_files[0]}"' using "$xy" with points title '"${comments[0]}"' lc rgb '"${colors[0]}"' pt "$pt" ps "$ps", \
        "${fun[0]}" with lines title '' lc rgb 'black' dt '"$lt"' lw "$ls", \\"
fi
echo $plot >> "$gnuplot_script_png"
echo $plot >> "$gnuplot_script"

for ((i=1; i<number_files-1; i++)); do
    plot="'"${input_files[i]}"' using "$xy" with points title '"${comments[i]}"' lc rgb '"${colors[i]}"' pt "$pt" ps "$ps", \
           "${fun[i]}" with lines title '' lc rgb 'black' dt '"$lt"' lw "$ls", \\"
    echo $plot >> "$gnuplot_script_png"
    echo $plot >> "$gnuplot_script"
done

if [ "$number_files" -eq 1 ]; then
    echo 
else
    plot="'"${input_files[number_files-1]}"' using "$xy" with points title '"${comments[number_files-1]}"' lc rgb '"${colors[number_files-1]}"' pt "$pt" ps "$ps", \
         "${fun[number_files-1]}" with lines title '' lc rgb 'black' dt '"$lt"' lw "$ls""
    echo $plot >> "$gnuplot_script_png"
    echo $plot >> "$gnuplot_script"
fi

# Esecuzione dello script di Gnuplot
gnuplot "$gnuplot_script_png"
rm "$gnuplot_script_png"

open "$gnuplot_script"
open "$output_file"
