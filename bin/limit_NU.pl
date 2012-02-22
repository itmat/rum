#!/usr/bin/perl

# Written by Gregory R. Grant
# University of Pennsylvania, 2010

if(@ARGV<1) {
  die "
Usage: limit_NU.pl <RUM NU file> <cutoff>

Where: <RUM NU file> is a file or non-unique mappers coming out of the RUM pipeline

       <cutoff> is a positive integer.  Alignments for reads for which the either the forward,
                or reverse if it is paired-end, appear more than <cutoff> times in the RUM NU
                file are filtered out.  Alignments of the joined reads count as one forward
                and one reverse.

";
}

$cutoff = $ARGV[1];

open(INFILE, $ARGV[0]);
while($line = <INFILE>) {
    $line =~ /seq.(\d+)([^\d])/;
    $seqnum = $1;
    $type = $2;
    if($type eq "a" || $type eq "\t") {
	$hash_a{$seqnum}++;
    }
    if($type eq "b" || $type eq "\t") {
	$hash_b{$seqnum}++;
    }
}
close(INFILE);

open(INFILE, $ARGV[0]);
while($line = <INFILE>) {
    $line =~ /seq.(\d+)[^\d]/;
    $seqnum = $1;
    if($hash_a{$seqnum}+0 <= $cutoff && $hash_b{$seqnum}+0 <= $cutoff) {
	print $line;
    }
}
close(INFILE);

