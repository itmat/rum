#!/usr/bin/perl

# Written by Gregory R. Grant
# University of Pennsylvania, 2010

# assuming a line of $ARGV[0] looks like this:
# seq.13392702    chr3    40576630-40576665, 40583257-40583328

if(!($ARGV[0] =~ /\S/)) {
    die "
Usage: perl make_bed.pl infile [outfile] [options]

Options:
   -seqnum : output also the sequence number at the beginning of every line
   -zbho   : output in zero-based half-open format (default is one-based closed)

This script makes a bed file with one span per line from a file that has rows
of tab delimited entries that start like this:

seq.13551265   chr13   +   57531714-57531787, 57537471-57537504

or like this:

chr13   +    57531714-57531787, 57537471-57537504

The first argument is input file, the second is the output file, if no second
argument is given then output goes to standard out.

";
}
$seqnum = "false";
$zbho = "false";
for($i=1; $i<@ARGV; $i++) {
    if($ARGV[$i] eq '-seqnum') {
	$seqnum = "true";
    }
    if($ARGV[$i] eq '-zbho') {
	$zbho = "true";
    }
}
open(INFILE, $ARGV[0]);
$outmode = "screen";
if($ARGV[1] =~ /\S/ && !($ARGV[1] =~ /^-/)) {
    open(OUTFILE, ">$ARGV[1]");
    $outmode = "file";
}


while($line = <INFILE>) {
    chomp($line);
    $line =~ s/(seq.\d+.?)\t//;
    $seqname = $1;
    @a = split(/\t/,$line);
    @b = split(/, /,$a[1]);
    $N = @b;
    $strand = $a[2];
    for($i=0; $i<$N; $i++) {
        @c = split(/-/,$b[$i]);
	if($zbho eq "true") {
	    $c[0]--;
	}
	if($seqnum eq "false") {
	    $str = "$a[0]\t$c[0]\t$c[1]\t$strand\n";
	} else {
	    $str = "$seqname\t$a[0]\t$c[0]\t$c[1]\t$strand\n";
	}
        if($outmode eq "file") {
            print OUTFILE $str;
        }
        else {
            print $str;
        }
    }
}
