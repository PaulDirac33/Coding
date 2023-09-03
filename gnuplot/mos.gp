set title 'MOSFET IRF 3205' font 'Times New Roman,30'
set xlabel 'V_{DS} (V)' font 'Times New Roman,30'
 set xlabel offset 0, -1.7
 set xtics font 'Times New Roman,30'
 set xtics offset 0, -0.5
 unset logscale x
set ylabel 'I_D (mA)' font 'Times New Roman,30'
 set ylabel offset -5, 0
 set ytics font 'Times New Roman,30'
 set ytics offset 0, 0
 set logscale y
set key font 'Times New Roman,30'
set key off
set samples 1E5
 set lmargin 20
 set bmargin 7
 set rmargin 5

plot '../data/char/3V00.dat' using 1:2 with points title ' V_{GS} = 3.00 V' lc rgb '#000000' pt 7 ps 1.5, 0.01136*log(413.301*x) with lines title '' lc rgb 'black' dt '-' lw 3, \
'../data/char/3V15.dat' using 1:2 with points title ' V_{GS} = 3.15 V' lc rgb '#ff0000' pt 7 ps 1.5, 0.03957*log(351.24*x) with lines title '' lc rgb 'black' dt '-' lw 3, \
'../data/char/3V25.dat' using 1:2 with points title ' V_{GS} = 3.25 V' lc rgb '#00ff00' pt 7 ps 1.5, 0.062496*log(3224.43*x) with lines title '' lc rgb 'black' dt '-' lw 3, \
'../data/char/3V40.dat' using 1:2 with points title ' V_{GS} = 3.40 V' lc rgb '#0000ff' pt 7 ps 1.5, 0.20919*log(2874.17*x) with lines title '' lc rgb 'black' dt '-' lw 3, \
'../data/char/3V50.dat' using 1:2 with points title ' V_{GS} = 3.50 V' lc rgb '#00ffff' pt 7 ps 1.5, 0.696287*log(645.482*x) with lines title '' lc rgb 'black' dt '-' lw 3, \
'../data/char/3V60.dat' using 1:2 with points title ' V_{GS} = 3.60 V' lc rgb '#ff00ff' pt 7 ps 1.5, 0.943088*log(2494*x) with lines title '' lc rgb 'black' dt '-' lw 3
