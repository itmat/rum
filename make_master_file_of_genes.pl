#!/usr/bin/perl

# Written by Gregory R. Grant
# University of Pennsylvania, 2010

if(@ARGV<1) {
    die "
Usage: make_master_file_of_genes.pl <files file>

This file takes a set of gene annotation files from UCSC and merges them into one.
They have to be downloaded with the following fields:
1) name
2) chrom
3) strand
4) exonStarts
5) exonEnds

This script is part of the pipeline of scripts used to create RUM indexes.
You should probably not be running it alone.  See the library file:
'how2setup_genome-indexes_forPipeline.txt'.

";
}

$TOTAL = 0;
open(FILESFILE, $ARGV[0]);
while($file = <FILESFILE>) {
    print STDERR "processing $file";
    chomp($file);
    $file =~ /(.*).txt$/;
    $type = $1;
    open(INFILE, $file);
    $line = <INFILE>;
    chomp($line);
    @header = split(/\t/,$line);
    $n = @header;
    for($i=0; $i<$n; $i++) {
        if($header[$i] =~ /name/) {
            $namecol = $i;
        }
        if($header[$i] =~ /chrom/) {
            $chromcol = $i;
        }
        if($header[$i] =~ /strand/) {
            $strandcol = $i;
        }
        if($header[$i] =~ /exonStarts/) {
            $exonStartscol = $i;
        }
        if($header[$i] =~ /exonEnds/) {
            $exonEndscol = $i;
        }
    }
    $CNT=0;
    while($line = <INFILE>) {
        chomp($line);
	if($line =~ /^#/) {
	    next;
	}
        @a = split(/\t/,$line);
	$a[$exonStartscol] =~ /^(\d+)/;
	$txStart = $1;
	$a[$exonEndscol] =~ /(\d+),?$/;
	$txEnd = $1;
	@b = split(/,/,$a[$exonStartscol]);
	$exonCnt = @b;
        $info = $a[$chromcol] . "\t" . $a[$strandcol] . "\t" . $txStart . "\t" . $txEnd . "\t" . $exonCnt . "\t" . $a[$exonStartscol] . "\t" . $a[$exonEndscol];
        if($GENESHASH{$info} =~ /\S/) {
            $GENESHASH{$info} = $GENESHASH{$info} . "::::" . $a[$namecol] . "($type)";
        }
        else {
            $GENESHASH{$info} = $GENESHASH{$info} . $a[$namecol].  "($type)";
        }
	$CNT++;
    }
    close(INFILE);
    print STDERR "$CNT lines in file\n";
    $TOTAL = $TOTAL + $CNT;
}
close(FILESFILE);
print STDERR "TOTAL: $TOTAL\n";

foreach $geneinfo (keys %GENESHASH) {
    print "$geneinfo\t$GENESHASH{$geneinfo}\n";
}
