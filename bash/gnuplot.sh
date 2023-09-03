#!/bin/bash

# We must be in /Users/.../bash
#                               |
#                               |
#    _____________ _____________v_____________ _____________
#   |             |             |             |             |
#  bash        gnuplot         data         images        config
#   |             |             |             |              |
#  *.sh          *.gp         *.dat         *.png         *.json
#---------------------------------------------------------------------------------------------
setup_file="../config/gnuplot.json"                               # path of setup file
#---------------------------------------------------------------------------------------------
echo "############################################"
echo -n "Insert the prefix of input files: "
read prefix
echo -n "Insert the prefix of output files: "
read file_out
echo -n "Insert title: "
read title
echo "Add functions to plot?"
read curve
if [ "$curve" == 'yes' ] || [ "$curve" == 'y' ]; then
  echo "Default or not? (d for default)"
  read choice
fi
#---------------------------------------------------------------------------------------------
data_dir=$(jq -r '.File.data_path' "$setup_file" )     # import input files directory
script_dir=$(jq -r '.File.script_path' "$setup_file") # import output file directory
images_dir=$(jq -r '.File.images_path' "$setup_file")      # import images directory
colors_file=$(jq -r '.File.color_path' "$setup_file")                # import colors
xy=$(jq -r '.Graphic_parameters.xy' "$setup_file")
image_size=$(jq -r '.Graphic_parameters.image_size' "$setup_file")
font=$(jq -r '.Graphic_parameters.font' "$setup_file")
size=$(jq -r '.Graphic_parameters.text_size' "$setup_file")
logscale_x=$(jq -r '.Graphic_parameters.logscale_x' "$setup_file")
logscale_y=$(jq -r '.Graphic_parameters.logscale_y' "$setup_file") # import axis scale 
pt=$(jq -r '.Graphic_parameters.point_type' "$setup_file")         # import points type
ps=$(jq -r '.Graphic_parameters.point_size' "$setup_file")         # import points size 
lt=$(jq -r '.Graphic_parameters.line_type' "$setup_file")          # import points type
ls=$(jq -r '.Graphic_parameters.line_size' "$setup_file")
xl_off=$(jq -r '.Graphic_parameters.x_label_offset' "$setup_file")  # offets
xt_off=$(jq -r '.Graphic_parameters.x_tics_offset' "$setup_file")
yl_off=$(jq -r '.Graphic_parameters.y_label_offset' "$setup_file")
yt_off=$(jq -r '.Graphic_parameters.y_tics_offset' "$setup_file")
legend=$(jq -r '.Graphic_parameters.legend' "$setup_file")
samples=$(jq -r '.Graphic_parameters.samples' "$setup_file")
l=$(jq -r '.Graphic_parameters.lmargin' "$setup_file")
b=$(jq -r '.Graphic_parameters.bmargin' "$setup_file")
r=$(jq -r '.Graphic_parameters.rmargin' "$setup_file")
#---------------------------------------------------------------------------------------------
input_files=($(ls "$data_dir"/"$prefix"*.dat))                            # import input files
number_files=${#input_files[@]}                                     # number of imported files						        				
output_file=$images_dir"/"$file_out".png" 	                       # relative path of file_out
gnuplot_script_png="$script_dir""/png.gp"			 # relative path of gnuplot script for the image
gnuplot_script="$script_dir""/"$file_out".gp"  # relative path of gnuplot script for the graph
#---------------------------------------------------------------------------------------------
names=()										                                     # name of physical quantities
x_names=()
y_names=()
units=()                                                                    # units of measure
x_units=()
y_units=()
comments=()
echo                                                                         # comments
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
if [ "$curve" == 'yes' ] || [ "$curve" == 'y' ]; then
  if [ "$choice" == 'd' ]; then
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
  else
    echo
    echo "Insert function: "
    echo
    fun=()
    for ((i=0; i<number_files; i++)); do
        echo -n "$((i+1))) "
        read function
        fun+=($function)
    done
  fi
fi
#-------------------------------------------------------------------------------------------
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
echo "set key "$legend"" >> "$gnuplot_script_png"
echo "set key "$legend"" >> "$gnuplot_script"

echo -e "set terminal pngcairo enhanced size $image_size\n
		     set output '"$output_file"'" >> "$gnuplot_script_png"

sample_margin="set samples "$samples"\n
		 	         set lmargin "$l"\n
		 	         set bmargin "$b"\n
		 	         set rmargin "$r"\n"

echo -e $sample_margin >> "$gnuplot_script_png"
echo -e $sample_margin >> "$gnuplot_script"

if [ "$number_files" -eq 1 ]; then
  if [ "$curve" == 'yes' ] || [ "$curve" == 'y' ]; then
    plot="plot '"${input_files[0]}"' using "$xy" with points title '"${comments[0]}"' lc rgb '"${colors[0]}"' pt "$pt" ps "$ps", \
         "${fun[0]}" with lines title '' lc rgb 'black' dt '"$lt"' lw "$ls""
  else
    plot="plot '"${input_files[0]}"' using "$xy" with points title '"${comments[0]}"' lc rgb '"${colors[0]}"' pt "$pt" ps "$ps""
  fi
else
  if [ "$curve" == 'yes' ] || [ "$curve" == 'y' ]; then
    plot="plot '"${input_files[0]}"' using "$xy" with points title '"${comments[0]}"' lc rgb '"${colors[0]}"' pt "$pt" ps "$ps", \
         "${fun[0]}" with lines title '' lc rgb 'black' dt '"$lt"' lw "$ls", \\"
  else
    plot="plot '"${input_files[0]}"' using "$xy" with points title '"${comments[0]}"' lc rgb '"${colors[0]}"' pt "$pt" ps "$ps",\\"  
  fi
fi
echo $plot >> "$gnuplot_script_png"
echo $plot >> "$gnuplot_script"

for ((i=1; i<number_files-1; i++)); do
  if [ "$curve" == 'yes' ] || [ "$curve" == 'y' ]; then
      plot="'"${input_files[i]}"' using "$xy" with points title '"${comments[i]}"' lc rgb '"${colors[i]}"' pt "$pt" ps "$ps", \
             "${fun[i]}" with lines title '' lc rgb 'black' dt '"$lt"' lw "$ls", \\"
  else
    plot="'"${input_files[i]}"' using "$xy" with points title '"${comments[i]}"' lc rgb '"${colors[i]}"' pt "$pt" ps "$ps",\\"
  fi
  echo $plot >> "$gnuplot_script_png"
  echo $plot >> "$gnuplot_script"
done

if [ "$number_files" -eq 1 ]; then
    echo 
else
  if  [ "$curve" == 'yes' ] || [ "$curve" == 'y' ]; then
      plot="'"${input_files[number_files-1]}"' using "$xy" with points title '"${comments[number_files-1]}"' lc rgb '"${colors[number_files-1]}"' pt "$pt" ps "$ps", \
           "${fun[number_files-1]}" with lines title '' lc rgb 'black' dt '"$lt"' lw "$ls""
  else
    plot="'"${input_files[number_files-1]}"' using "$xy" with points title '"${comments[number_files-1]}"' lc rgb '"${colors[number_files-1]}"' pt "$pt" ps "$ps""
  fi
  echo $plot >> "$gnuplot_script_png"
  echo $plot >> "$gnuplot_script"
fi

# Esecuzione dello script di Gnuplot
gnuplot "$gnuplot_script_png"
rm "$gnuplot_script_png"

open "$gnuplot_script"
open "$output_file"
