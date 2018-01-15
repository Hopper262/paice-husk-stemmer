Paice/Husk (Lancaster) Stemmer
------------------------------

This page offers interchangeable implementations of the Paice/Husk stemmer, developed by Chris Paice and Gareth Husk. The [official stemmer website (archived copy)](https://web.archive.org/web/20060822024855/http://www.comp.lancs.ac.uk:80/computing/research/stemming/Links/paice.htm) has more information.

The implementations here provide different results from the "official" releases. Each of the releases on the Lancaster site produce slightly differing stems, making it impossible to use a mix of, say, C and Java stemmers on the same project. In this project, source code is provided in C, Java, Perl, and Pascal; each of these implementations produces identical stemming results, allowing different languages to work together. The source code is commented and laid out to mostly match this flowchart of the algorithm:

![flowchart](https://web.archive.org/web/20060827050639if_/http://www.comp.lancs.ac.uk:80/computing/research/stemming/Files/paice.JPG)

Perl users may prefer the Perl module `Lingua::Stem::PaiceHusk` instead, suitable for incorporation into other programs.
