#!/usr/bin/perl

# Written by Gregory R. Grant
# University of Pennsylvania, 2010

$|=1;

if(@ARGV < 3) {
    die "
Usage: removedups.pl <rum nu infile> <rum nu outfile> <rum unique outfile>

Where: 
  <rum nu infile> is sorted by id
  <rum unique outfile> is assumed to be existing and is added to in case
                       something is actually unique

This was made for the RUM NU file which accrued some duplicates
along its way through the pipeline.

";

}

open(RUMNU, $ARGV[0]);
$flag = 0;
$entry = "";
$outfile = $ARGV[1];
$outfileu = $ARGV[2];
$seqnum = 1;
open(OUTFILE, ">$outfile");
open(OUTFILEU, ">>$outfileu");
while($flag == 0) {
    $line = <RUMNU>;
    chomp($line);
    $type = "";
    $line =~ /seq.(\d+)(.)/;
    $sn = $1;
    $type = $2;
    if($sn == $seqnum && $type eq "a") {
	if($entry eq '') {
	    $entry = $line;
	} else {
	    $hash{$entry} = 1;
	    $entry = $line;
	}
    }
    if($sn == $seqnum && $type eq "b") {
	if($entry =~ /a/) {
	    $entry = $entry . "\n" . $line;
	} else {
	    $entry = $line;  # a line with 'b' never follows a merged of the same id, 
                             # otherwise this would wax the merged...
	}
	$hash{$entry} = 1;
	$entry = '';
    }
    if($sn == $seqnum && $type eq "\t") {
	if($entry eq '') {
	    $entry = $line;
	    $hash{$entry} = 1;
	    $entry = '';
	} else {
	    $hash{$entry} = 1;
	    $entry = $line;
	}
    }
    if($sn > $seqnum || $line eq '') {
	$len = -1 * (1 + length($line));
	seek(RUMNU, $len, 1);
	$hash{$entry} = 1;
	$cnt=0;
	foreach $key (keys %hash) {
	    if($key =~ /\S/) {
		$cnt++;
	    }	    
	}
	foreach $key (keys %hash) {
	    if($key =~ /\S/) {
		chomp($key);
		$key =~ s/^\s*//s;
		if($cnt == 1)  {
		    print OUTFILEU "$key\n";
		} else {
		    print OUTFILE "$key\n";
		}
	    }
	}
	undef %hash;
	$seqnum = $sn;
	$entry = '';
    }
    if($line eq '') {
	$flag = 1;
    }
}
close(OUTFILE);
close(OUTFILEU);
