#!/bin/bash

# ANSI C version
gcc -ansi -o paicehusk_ansic paicehusk_ansic.c
echo "Running ANSI C version..."
time ./paicehusk_ansic paicehusk_rules.txt wordlist.txt \
  1> ansic.out 2> ansic.err

# Pascal version
gpc -o paicehusk_pascal paicehusk_pascal.pas
echo "Running Pascal version..."
time ./paicehusk_pascal paicehusk_rules.txt wordlist.txt \
  1> pascal.out 2> pascal.err

# Java version
javac paicehusk_java.java
echo "Running Java version..."
time java PaiceHusk paicehusk_rules.txt wordlist.txt \
  1> java.out 2> java.err

# Perl version
echo "Running Perl version..."
time ./paicehusk_perl.pl paicehusk_rules.txt wordlist.txt \
  1> perl.out 2> perl.err

echo "Testing differences..."
FOUND=0

DIFFOUT=`diff ansic.out pascal.out`
DIFFERR=`diff ansic.err pascal.err`
if [ "$DIFFOUT" != "" -o "$DIFFERR" != "" ]; then
  echo "ANSI C and Pascal versions differ."
  FOUND=1
fi

DIFFOUT=`diff ansic.out java.out`
DIFFERR=`diff ansic.err java.err`
if [ "$DIFFOUT" != "" -o "$DIFFERR" != "" ]; then
  echo "ANSI C and Java versions differ."
  FOUND=1
fi

DIFFOUT=`diff ansic.out perl.out`
DIFFERR=`diff ansic.err perl.err`
if [ "$DIFFOUT" != "" -o "$DIFFERR" != "" ]; then
  echo "ANSI C and Perl versions differ."
  FOUND=1
fi

if [ "$FOUND" -gt "0" ]; then
  echo "Testing complete (differences found)."
  exit 1
else
  echo "Testing complete (no differences found)."
  exit 0
fi
