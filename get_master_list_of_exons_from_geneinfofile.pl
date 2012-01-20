#!/usr/bin/perl

# Written by Gregory R. Grant
# Universiry of Pennsylvania, 2010

if(@ARGV < 1) {
    die "
Usage: get_master_list_of_exons_from_geneinfofile.pl <gene info file>

This script takes a UCSC gene annotation file and outputs a file of all unique
exons.  The annotation file has to be downloaded with the following fields:
1) chrom
2) strand
3) txStart
4) txEnd
5) exonCount
6) exonStarts
7) exonEnds
8) name

This script is part of the pipeline of scripts used to create RUM indexes.
For more information see the library file: 'how2setup_genome-indexes_forPipeline.txt'.

";
}

open(INFILE, $ARGV[0]);
while($line = <INFILE>) {
    chomp($line);
    @a = split(/\t/,$line);
    $a[5]=~ s/\s*,\s*$//;
    $a[5]=~ s/^\s*,\s*//;
    $a[6]=~ s/\s*,\s*$//;
    $a[6]=~ s/^\s*,\s*//;
    @S = split(/,/,$a[5]);
    @E = split(/,/,$a[6]);
    $N = @S;
    for($e=0; $e<@S; $e++) {
	$S[$e]++;
	$exon = "$a[0]:$S[$e]-$E[$e]";
	$EXONS{$exon}++;
    }
}
close(INFILE);


open(OUTFILE, ">master_list_of_exons.txt");
foreach $exon (keys %EXONS) {
    print OUTFILE "$exon\n";
}
close(OUTFILE);
