set title '' font 'Times New Roman,30'
set xlabel 'n (2)' font 'Times New Roman,30'
 set xlabel offset 0, -1.7
 set xtics font 'Times New Roman,30'
 set xtics offset 0, -0.5
 unset logscale x
set ylabel 'Σ(1/n^2) (1.250000000)' font 'Times New Roman,30'
 set ylabel offset -5, 0
 set ytics font 'Times New Roman,30'
 set ytics offset 0, 0
 set logscale y
set key font 'Times New Roman,30'
set samples 1E5
 set lmargin 20
 set bmargin 7
 set rmargin 5

plot '../C++/series.dat' using 1:2 with points title '1 1.000000000' lc rgb '#ff0000' pt 7 ps 1, 1.6449340668 with lines title '' lc rgb 'black' dt '-' lw 3
