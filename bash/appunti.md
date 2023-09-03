# LEZIONE 1 >> Introduzione alla shell bash <<

## 1) File di configurazione}

/etc/bash.bashrc

## 2) Comdandi fra parentesi tonde () --> la shell bash crea una sotto shell, non interattiva che esegue il comando

(ps;ps)

## 3) Comdandi fra parentesi graffe {} --> la shell esegue i comandi

{ ps;ps; }

## 4) Cronologia comandi

history
_.

# LEZIONE 2 >> Esecuzione condizionale <<

## 1) Esecuzione in && (and) --> si va avanti solo se non ci sono errori

ps && ps && ps

## 2) Esecuzione in or --> se il precedente fallisce si va avanti, fino a quando l'exit status è 0

lss || echo ciao || ls

## 3) Exit status (0 255)

echo $?
_.

# LEZIONE 3 >> Redirezioni "1"<<

## 1) File Descriptor Table: Ogni processo ha una FDT, tabella di entry.
	  Ogni entry ha un FDT identifier, raggruppa le informazioni dei files.
	  Ogni processo ha 3 stream, identificati dagli DFT 0 (STIN), 1 (STOUT), 2 (STERR)

## 2) Redirezione STERR

lss 2> err.txt

## 3) Redirezione STIN

tr "1234" "abcd" < in.txt

## 3) Redirezione STOUT

tr "1234" "abcd" < in.txt > out.txt
_.

# LEZIONE 4 >> Redirezioni "2"<<

## 1) Redirezioni in out distruttiva

ls > t.txt

## 2) Redirezioni in out non distruttiva

ls >> t.txt

## 3) File di redirezione 

cd /dev/fd
ls -l /dev/fd

# Mac-Mini-Riccardo /dev/fd % ll
# total 0
# crw--w----  1 riccardo  tty    0x10000000 16 Giu 16:48 0
# crw--w----  1 riccardo  tty    0x10000000 16 Giu 16:48 1
# crw--w----  1 riccardo  tty    0x10000000 16 Giu 16:48 2
# dr--r--r--  1 root      wheel           0 16 Giu 11:55 3
# dr--r--r--  1 root      wheel           0 16 Giu 11:55 4
# dr--r--r--  1 root      wheel           0 16 Giu 11:55 5

## 4) Redirezione STOUT della shell

exec  > ~/bash/out.txt

Mac-Mini-Riccardo /dev/fd % ll
crw--w----  1 riccardo  tty    0x10000000 16 Giu 16:51 0
-rwxrwxrwx  1 riccardo  staff          58 16 Giu 16:51 1
crw--w----  1 riccardo  tty    0x10000000 16 Giu 16:51 2
dr--r--r--  1 root      wheel           0 16 Giu 11:55 3
dr--r--r--  1 root      wheel           0 16 Giu 11:55 4
dr--r--r--  1 root      wheel           0 16 Giu 11:55 5

exec  > /dev/tty # per tornare a tampare su terminale, su ubuntu è diverso,
				 # ma il concetto è lo stesso ci sono i path /dev/pts/0
_.

# LEZIONE 6 >> Pipelinig <<

## 1) STOUT del primo comando viene mandata nella STIN del secondo, funziona solo se il primo comando è corretto

ls | tr "aeiou" "AEIOU"

DEsktOp
DOcUmEnts
DOwnlOAds
LIbrAry
MOvIEs
MUsIc
OnEDrIvE
OnEDrIvE - UnIvErsItA' dEglI StUdI dI ROmA TOr VErgAtA
OrIgInPrO 2019 CrAck
PIctUrEs
PUblIc
PychArmPrOjEcts
bAsh
lAtEx
tEst_gnUplOt.png

lss |& tr "aeiou" "AEIOU" #funziona anche se lss non è un comando --> zsh: cOmmAnd nOt fOUnd: lss
_.

# LEZIONE 7 >> Scripting <<

## 1) Eesecuzione nella shell corrente

surce s.sh

## 2) Eesecuzione nella sottoshell nn interattiva (servono i permessi di esecuzione)

./s.sh
_.

# LEZIONE 8 >> Variabili <<

## 1) Dichiarazione

var="valore"		# stringa

declare -i num = 12	# intero

## 2) Calcolo aritmetico

a=12
b=13

echo $(( $a+$b ))		# stampa il valore 25

## 3) Separazione in parentesi graffe

a=12
ab=13

echo $ab 				# stampa 13


a=12
ab=13

echo ${a}ab 				# stampa 12ab, espande solo il valore di a

unset a ab					# resetta le variabili

## 4) Readonly

declare -r var="ciao"		# è costante

## 5) Variabili di ambiente

export

declare -x var_glog="ciao"
__.
_.



















