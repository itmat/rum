#!/usr/bin/perl

# Written by Gregory R Grant
# University of Pennsylvania, 2010

if(@ARGV<1) {
    die "
Usage: sam2junctions.pl <sam file> [option]

Option:      -id   : output also read id

        -minsize i : Only consider it to be a junction if it's longer than this.
                     Default = 0.

";
}

$printid = "false";
$minsize = 0;
for($i=1; $i<@ARGV; $i++) {
    $optionrecognized = 0;
    if($ARGV[$i] eq "-id") {
	$printid = "true";
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-minsize") {
	$minsize = $ARGV[$i+1];
	$i++;
	$optionrecognized = 1;
    }
    if($optionrecognized == 0) {
	die "\nERROR: option '$ARGV[$i]' not recognized\n";
    }
}

open(INFILE, $ARGV[0]) or die "\nError: Cannot open '$ARGV[0]' for reading\n\n";
$line = <INFILE>;
while($line =~ /^@/) {
    $line = <INFILE>;
}
while($line = <INFILE>) {
    chomp($line);
    $line =~ /IH:i:(\d+)/;
    $N = $1;
    if($N >=2) {
	next;
    }
    @a = split(/\t/, $line);
    $id = $a[0];
    $sam_chr = $a[2];
    $sam_chr =~ s/:[^:]*$//;
    $sam_start = $a[3];
    $sam_cigar = $a[5];
    $running_offset = 0;
    while($sam_cigar =~ /^(\d+)([^\d])/) {
	$num = $1;
	$type = $2;
	if($type eq 'N') {
	    $start = $sam_start + $running_offset - 1;
	    $end = $start + $num + 1;
	    $junction = "$sam_chr:$start-$end";
	    if($num >= $minsize) {
		if($printid eq "true") {
		    print "$id\t$junction\n";
		} else {
		    print "$junction\n";
		}
	    }
	}
	if($type eq 'N' || $type eq 'M' || $type eq 'D') {
	    $running_offset = $running_offset + $num;
	}
	$sam_cigar =~ s/^\d+[^\d]//;
    }
}
close(INFILE);
