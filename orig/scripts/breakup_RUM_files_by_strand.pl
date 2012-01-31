#!/usr/bin/perl


$infile = $ARGV[0];
$outfile1 = $ARGV[1];
$outfile2 = $ARGV[2];

open(INFILE, $infile);
open(OUTFILE1, ">$outfile1");
open(OUTFILE2, ">$outfile2");
while($line = <INFILE>) {
    if($line =~ /\t-\t/) {
              print OUTFILE2 $line;
    } else {
	print OUTFILE1 $line;
    }
}
close(INFILE);
close(OUTFILE1);
close(OUTFILE2);
