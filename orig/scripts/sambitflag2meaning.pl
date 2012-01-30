#!/usr/bin/perl

# Written by Gregory R. Grant
# University of Pennsylvania, 2010

if(@ARGV < 1) {
    die "
Usage: sambitflag2meaning.pl <int>

<int> is the sam bit flag you want explained.

";
}

$vals[0] = "the read is paired in sequencing";
$vals[1] = "the read is mapped in a proper pair";
$vals[2] = "the query sequence itself is unmapped";
$vals[3] = "the mate is unmapped";
$vals[4] = "strand of the query";
$vals[5] = "strand of the mate";
$vals[6] = "the read is the first read in a pair";
$vals[7] = "the read is the second read in a pair";
$vals[8] = "the alignment is not primary";
$vals[9] = "the read fails platform/vendor quality checks";
$vals[10] = "the read is either a PCR duplicate or an optical duplicate";

print "\n";
for($j=0; $j<10; $j++) {
    print "\t$j";    
}
print "\n";
if($ARGV[0] =~ /^\d+$/) {
    print "$ARGV[0]:";
    for($j=0; $j<10; $j++) {
	if($ARGV[0] & 2**$j) {
	    print "\tyes";
	} else {
	    print "\tno";
	}
    }
    print "\n\n";
    for($j=0; $j<10; $j++) {
	if($j == 4 && ($ARGV[0] & 4) == 0) {
	    if($ARGV[0] & 2**$j) {
		print "strand of the query: -\n";
	    } else {
		print "strand of the query: +\n";
	    }
	}
	if($j == 5 && ($ARGV[0] & 8) == 0) {
	    if($ARGV[0] & 2**$j) {
		print "strand of the mate: -\n";
	    } else {
		print "strand of the mate: +\n";
	    }
	}
	if($j != 4 && $j != 5) {
	    if($ARGV[0] & 2**$j) {
		print "$vals[$j]\n";
	    }
	}
    }
    print "\n";
    exit();
} 

for($i=0; $i<300; $i++) {
    print "$i:";
    for($j=0; $j<10; $j++) {
	if($i & 2**$j) {
	    print "\tyes";
	} else {
	    print "\tno";
	}
    }
    print "\n";
}

