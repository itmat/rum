#!/usr/bin/perl

$|=1;

use FindBin qw($Bin);
use lib "$Bin/../../lib";

use RUM::Common qw(roman Roman isroman arabic);
use RUM::ChrCmp qw(cmpChrs);

if(@ARGV < 4) {
    die "
Usage: sort_by_location.pl <in file> <out file> [options]

  Where:
     <in file> is a tab delimited file with either:
        one column giving locations in the format chr:start-end
        chr, start location and end location given in three different columns

  Options: 

      One of the following must be specified:

      -location_column n : n is the column that has the location (start counting at one)
                           in the case there is one column having the form chr:start-end 

      -location_columns c,s,e : c is the column that has the chromsome (start counting at one)
                                s is the column that has the start location (start counting at one)
                                e is the column that has the end location (start counting at one)
                                c,s,e must be separated by commas, without spaces

      -skip n : skip the first n lines (will preserve those lines at the top of the output).
";
}


$infile = $ARGV[0];
$outfile = $ARGV[1];

$option_specified = "false";
$location = "false";
$locations = "false";
$skip = 0;
for($i=2; $i<@ARGV; $i++) {
    if($ARGV[$i] eq "-location_column") {
	$location_column = $ARGV[$i+1] - 1;
	if(!($location_column =~ /^\d+$/)) {
	    die "\nError: location_column must be a positive integer\n\n";
	} else {
	    if($ARGV[$i+1]  == 0) {
		die "\nError: location_column must be a positive integer\n\n";
	    }
	}
	$location = "true";
	$option_specified = "true";
	$i++;
    }
    if($ARGV[$i] eq "-location_columns") {
	if($ARGV[$i+1] =~ /(\d+),(\d+),(\d+)/) {
	    $chr_column = $1 - 1;
	    $start_column = $2 - 1;
	    $end_column = $3 - 1;
	} else {
	    die "\nError: location_columns must be three positive integers separated by commas, with no spaces.\n\n";
	    exit();
	}
	$locations = "true";
	$option_specified = "true";
	$i++;
    }
    if($ARGV[$i] eq "-skip") {
	$skip = $ARGV[$i+1];
	if(!($skip =~ /^\d+$/)) {
	    die "\nError: -skip must be a positive integer\n\n";
	} else {
	    if($ARGV[$i+1] == 0) {
		die "\nError: location_column must be a positive integer\n\n";
	    }
	}
    }
}
if($option_specified eq "false") {
    die "\nError: one of the two options must be specified.\n\n";
}

open(INFILE, $infile);
open(OUTFILE, ">$outfile");
for($i=0; $i<$skip; $i++) {
    $line = <INFILE>;
    print OUTFILE $line;
}

while($line = <INFILE>) {
    chomp($line);
    @a = split(/\t/,$line);
    if($location eq "true") {
	$loc = $a[$location_column];
	$loc =~ /^(.*):(\d+)-(\d+)/;
	$chr = $1;
	$start = $2;
	$end = $3;
    }
    if($locations eq "true") {
	$chr = $a[$chr_column];
	$start = $a[$start_column];
	$end = $a[$end_column];
    }
    $hash{$chr}{$line}[0] = $start;
    $hash{$chr}{$line}[1] = $end;
}
close(INFILE);

foreach $chr (sort {cmpChrs($a,$b)} keys %hash) {
    foreach $line (sort {$hash{$chr}{$a}[0]<=>$hash{$chr}{$b}[0] || ($hash{$chr}{$a}[0]==$hash{$chr}{$b}[0] && $hash{$chr}{$a}[1]<=>$hash{$chr}{$b}[1])} keys %{$hash{$chr}}) {
	chomp($line);
	if($line =~ /\S/) {
	    print OUTFILE "$line\n";
	}
    }
}
close(OUTFILE);


sub merge() {
    $tempfilename1 = $CHR[$cnt] . "_temp.0";
    $tempfilename2 = $CHR[$cnt] . "_temp.1";
    $tempfilename3 = $CHR[$cnt] . "_temp.2";
    open(TEMPMERGEDOUT, ">$tempfilename3");
    open(TEMPIN1, $tempfilename1);
    open(TEMPIN2, $tempfilename2);
    $mergeFLAG = 0;

    getNext1();
    getNext2();
    while($mergeFLAG < 2) {
	chomp($out1);
	chomp($out2);
	if($start1 < $start2) {
	    if($out1 =~ /\S/) {
		print TEMPMERGEDOUT "$out1\n";
	    }
	    getNext1();
	} elsif($start1 == $start2) {
	    if($end1 <= $end2) {
		if($out1 =~ /\S/) {
		    print TEMPMERGEDOUT "$out1\n";
		}
		getNext1();
	    } else {
		if($out2 =~ /\S/) {
		    print TEMPMERGEDOUT "$out2\n";
		}
		getNext2();
	    }
	} else {
	    if($out2 =~ /\S/) {
		print TEMPMERGEDOUT "$out2\n";
	    }
	    getNext2();
	}
    }
    close(TEMPMERGEDOUT);
    `mv $tempfilename3 $tempfilename1`;
    unlink($tempfilename2);
}

sub getNext1 () {
    $line1 = <TEMPIN1>;
    chomp($line1);
    if($line1 eq '') {
	$mergeFLAG++;
	$start1 = 1000000000000;  # effectively infinity, no chromosome should be this large;
	return "";
    }
    @a = split(/\t/,$line1);
    $a[2] =~ /^(\d+)-/;
    $start1 = $1;
    if($a[0] =~ /a/ && $separate eq "false") {
	$a[0] =~ /(\d+)/;
	$seqnum1 = $1;
	$line2 = <TEMPIN1>;
	chomp($line2);
	@b = split(/\t/,$line2);
	$b[0] =~ /(\d+)/;
	$seqnum2 = $1;
	if($seqnum1 == $seqnum2 && $b[0] =~ /b/) {
	    if($a[3] eq "+") {
		$b[2] =~ /-(\d+)$/;
		$end1 = $1;
	    } else {
		$b[2] =~ /^(\d+)-/;
		$start1 = $1;
		$a[2] =~ /-(\d+)$/;
		$end1 = $1;
	    }
	    $out1 = $line1 . "\n" . $line2;
	} else {
	    $a[2] =~ /-(\d+)$/;
	    $end1 = $1;
	    # reset the file handle so the last line read will be read again
	    $len = -1 * (1 + length($line2));
	    seek(TEMPIN1, $len, 1);
	    $out1 = $line1;
	}
    } else {
	$a[2] =~ /-(\d+)$/;
	$end1 = $1;
	$out1 = $line1;
    }
}

sub getNext2 () {
    $line1 = <TEMPIN2>;
    chomp($line1);
    if($line1 eq '') {
	$mergeFLAG++;
	$start2 = 1000000000000;  # effectively infinity, no chromosome should be this large;
	return "";
    }
    @a = split(/\t/,$line1);
    $a[2] =~ /^(\d+)-/;
    $start2 = $1;
    if($a[0] =~ /a/ && $separate eq "false") {
	$a[0] =~ /(\d+)/;
	$seqnum1 = $1;
	$line2 = <TEMPIN2>;
	chomp($line2);
	@b = split(/\t/,$line2);
	$b[0] =~ /(\d+)/;
	$seqnum2 = $1;
	if($seqnum1 == $seqnum2 && $b[0] =~ /b/) {
	    if($a[3] eq "+") {
		$b[2] =~ /-(\d+)$/;
		$end2 = $1;
	    } else {
		$b[2] =~ /^(\d+)-/;
		$start2 = $1;
		$a[2] =~ /-(\d+)$/;
		$end2 = $1;
	    }
	    $out2 = $line1 . "\n" . $line2;
	} else {
	    $a[2] =~ /-(\d+)$/;
	    $end2 = $1;
	    # reset the file handle so the last line read will be read again
	    $len = -1 * (1 + length($line2));
	    seek(TEMPIN2, $len, 1);
	    $out2 = $line1;
	}
    } else {
	$a[2] =~ /-(\d+)$/;
	$end2 = $1;
	$out2 = $line1;
    }
}

