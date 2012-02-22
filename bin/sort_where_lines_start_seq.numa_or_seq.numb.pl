#!/usr/bin/perl

# Written by Gregory R Grant 
# University of Pennsylvania, 2010

use strict;

if(@ARGV < 2) {
    die "
Usage: sort_where_lines_start_seq.numa_or_seq.numb.pl <infile> <outfile> [options]

Where <infile> is the name of the file that has rows starting with seq.\d+a or seq.\d+b

Options:
   -remove : remove the infile if the sort succeeds

This script sorts the rows so that rows with seq.Na and seq.Nb are before
rows with seq.Ma and seqMb whenever N<M.  Furthermore for fixed N seq.Na is
before seq.Nb.

";
}

my $infile = $ARGV[0];
my $outfile = $ARGV[1];

my $remove = "false";
for(my $i=2; $i<@ARGV; $i++) {
    my $optionrecognized = 0;
    if($ARGV[$i] eq "-remove") {
	$remove = "true";
	$optionrecognized = 1;
    }

    if($optionrecognized == 0) {
	die "\nERROR: option '$ARGV[$i]' not recognized\n";
    }
}

open(INFILE, $infile);
my $tempfilename = $infile . "_temp1";
open(OUTFILE, ">$tempfilename");
while(my $line = <INFILE>) {
    chomp($line);
    $line =~ s/^([^\t]+)\t//;
    my $name = $1;
    $name =~ s/seq.//;
    $name =~ /(\d+)(a|b)/;
    print OUTFILE "$1\t$2\t$line\n";
}
close(OUTFILE);
close(INFILE);
my $tempfilename2 = $infile . "_temp2";
my $x = `sort -T . -n $tempfilename > $tempfilename2`;
$x = `rm $tempfilename`;
open(INFILE, $tempfilename2);
open(OUTFILE, ">$outfile");
while(my $line = <INFILE>) {
    chomp($line);
    $line =~ s/^(\d+)\t(.)//;
    print OUTFILE "seq.$1$2$line\n";
}
close(OUTFILE);
close(INFILE);
$x = `rm $tempfilename2`;
my $N = -s $infile;
my  $M = -s $outfile;
if($N != $M) {
    die "\nERROR: The sorted file is not the same size as the infile.\n\n";
}

if($remove eq "true") {
    $x = `rm $infile`;
}
