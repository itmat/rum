#!/usr/bin/perl

# Written by Gregory R. Grant
# University of Pennsylvania, 2010

if(@ARGV<1 || $ARGV[0] eq "help") {
    print "\nusage: normalize.pl <cov_file> [options]\n\n";
    print "Outputs to standard out.\n\n";
    print "This script divides each coverage by a factor, which by default is M/10^9 where M is the total\n";
    print "number of bases of reads mapped.\n\n";
    print "options:\n";
    print "    -normfactor N                : divide coverages by N\n";
    print "    -open                        : cov file coords open (right endpoint not included)\n";
    print "    -zerohalfopen2onehalfclosed  : cov file coords zero based half open, output one based half closed\n";
    print "    -convert2singlebase          : output one row per base (for which cov > 0)\n";
    print "    -scale N                     : divide number bases mapped by N to get normfactor (default is N=10^9)\n";
    print "\n";
    exit();
}
open(INFILE, $ARGV[0]);
$open = "false";
$zho2ohc = "false";
$singlebase = "false";
$scale = 1000000000;
for($i=1; $i<@ARGV; $i++) {
    $optionrecognized = 0;
    if($ARGV[$i] eq "-normfactor") {
	$normfactor = $ARGV[$i+1];
	$i++;
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-scale") {
	$scale = $ARGV[$i+1];
	$i++;
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-open") {
	$open = "true";
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-zerohalfopen2onehalfclosed") {
	$zho2ohc = "true";
	$open = "true";
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-convert2singlebase") {
	$singlebase = "true";
	$optionrecognized = 1;
    }
    if($optionrecognized == 0) {
	print "\n\nERROR: Option $ARGV[$i] not recognized.\n\n";
	exit();
    }
}

if($open eq "true") {
    $adjust = 0;
}
else {
    $adjsut = 1;
}

if(!($normfactor =~ /\S/)) {
    $normfactor = 0;
    while($line = <INFILE>) {
	chomp($line);
	if($line =~ /^\S+\t(\d+)\t(\d+)\t(\d+)/) {
	    $normfactor = $normfactor + ($2 - $1 + $adjust) * $3;
	}
    }
    $normfactor = $normfactor / $scale;
}
close(INFILE);
print STDERR "normfactor = $normfactor\n";
open(INFILE, $ARGV[0]);
while($line = <INFILE>) {
    chomp($line);
    if($line =~ /^(\S+)\t(\d+)\t(\d+)\t(\d+)/) {
	$chr = $1;
	$start = $2;
	$end = $3;
	$cov = $4;
	$newcov = int($cov / $normfactor * 10000)/10000;
	if($zho2ohc eq "true") {
	    $start++;
	    if($singlebase eq "true") {
		for($j=$start; $j<=$end; $j++) {
		    print "$chr\t$j\t$newcov\n";
		}
	    }
	    else {
		print "$chr\t$start\t$end\t$newcov\n";
	    }
	}
	else {
	    if($singlebase eq "true") {
		if($open eq "true") {
		    for($j=$start; $j<$end; $j++) {
			print "$chr\t$j\t$newcov\n";
		    }
		}
		else {
		    for($j=$start; $j<=$end; $j++) {
			print "$chr\t$j\t$newcov\n";
		    }
		}
	    }
	    else {
		print "$chr\t$start\t$end\t$newcov\n";
	    }
	}
    }
    else {
	print "$line\n";
    }
}
close(INFILE);
