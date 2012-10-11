#!/usr/bin/perl

# Written by Gregory R Grant 
# University of Pennsylvania, 2010

# NOTE: add something to check if it's a fasta file with seq spanning
# multiple lines, this case is otherwise not being handled.

$|=1;
use strict;
use warnings;
use autodie;

use FindBin qw($Bin);
use lib ("$Bin/../lib", "$Bin/../lib/perl5");
use RUM::Common qw(open_r);

my $n = @ARGV;
if(@ARGV < 1) {
    print "\nUsage: parse2fasta.pl <infile1> [infile2] [options]\n\n";
    print "infile1 are the foward reads and infile2 are the reverse (if there are\nreverse reads).\n\n";
    print "Options:\n";
    print "     -firstrow n      : n is the first row that has sequence on it.\n";
    print "     -secondrow n     : n is the second row that has sequence on it.\n";
    print "     -name_mapping F  : If set will write a file <F> mapping modified names to\n";
    print "                        original names.\n\n";
    print "Note: these parameters are inferred automatically, the options are given\n";
    print "just in case you need to do it by hand for any reason.\n\n";
    print "PURPOSE: ";
    print "This program reformats files of reads into the appropriate fasta\nformat needed for the RUM pipeline.\n\n";
    print "INPUT: ";
    print "Files can be fastq files, or fasta files, or more genreally the input\nfiles can have blocks of N rows for each read, where the read is on the\nsame row of each block.  N can be any positive integer and does not need to\nbe specified.  The files can also have sequence as part of every line, the\nscript should figure it out, if it can't it will let you know.\n\n";
    print "OUTPUT: ";
    print "Output is written to standard out, you should redirect it to a file.\n\n";

    exit();
}
my $optionsstart = 1;
my $paired = "false";
if(defined($ARGV[1]) && -e $ARGV[1]) {
    $optionsstart = 2;
    $paired = "true";
} else {
    $optionsstart = 1;
}

my $firstNArow = 0;
my $secondNArow = 0;
my $userparamsgiven = 0;
my $map_names = "false";
my $name_mapping_file;
for(my $i=$optionsstart; $i<@ARGV; $i++) {
    my $optionrecognized = 1;
    if($ARGV[$i] eq "-firstrow") {
	$firstNArow = $ARGV[$i+1] - 1;
	$optionrecognized = 0;
	$i++;
	$userparamsgiven = 1;
    }
    if($ARGV[$i] eq "-secondrow") {
	$secondNArow = $ARGV[$i+1] - 1;
	$optionrecognized = 0;
	$i++;
    }
    if($ARGV[$i] eq "-name_mapping") {
	$map_names = "true";
	$i++;
	$name_mapping_file = $ARGV[$i];
	open(NAMEMAPPINGALL, ">$name_mapping_file") or die "ERROR: in script parsefastq.pl, cannot open \"$name_mapping_file\" for writing.\n\n";
	$optionrecognized = 0;
    }
    if($optionrecognized == 1) {
	die "\nERROR: in script parse2fasta.pl: option '$ARGV[$i-1]' not recognized.  Must be 'single' or 'paired'.\n";
    }
}
if(($firstNArow =~ /\S/ && !($secondNArow =~ /\S/)) && ($secondNArow =~ /\S/ && !($firstNArow =~ /\S/))) {
    die "\nERROR: in script parse2fasta.pl: you must set *both* -firstrow and -secondrow, or neither\n";
}

my $infile1 = open_r($ARGV[0]);
my $cnt = 0;
my @linearray;
my $line;
if($userparamsgiven == 0) {  # the following figures out how many rows per block and which row the sequence is on.
    while(1==1) { # This loop simply records in an array whether each row looks like sequence or not
	$line = <$infile1>;
	if (!defined $line) {
	    last;
	}
	chomp($line);
	$line =~ s/[^ACGTN.]$//;
	if($line =~ /^(A|C|G|T|N|\.){5}(A|C|G|T|N|\.)+$/) {
	    $linearray[$cnt] = 1;
	} else {
	    $linearray[$cnt] = 0;
	}
	$cnt++;
	if($cnt > 20000) {
	    last;
	}
    }

    my $num_lines_seq = 0;
    for(my $i=0; $i<@linearray; $i++) {
	if($linearray[$i] == 1) {
	    $num_lines_seq++;
	}
    }

    if($num_lines_seq == 0) {
	&try_to_see_if_part_of_each_line_is_seq();
	die "\nWarning: No lines of sequence found in the file '$ARGV[0]'\n\n";
    }

    # special case, only one line of sequence in the file:
    if($num_lines_seq == 1) {
	print ">seq.1a\n";
        my $infile = open_r($ARGV[0]);

	my $i=0;
	$line = <$infile>;
	until($linearray[$i] == 1) {
	    $line = <$infile>;
	    $i++;
	}
	chomp($line);
	$line =~ s/[^ACGTN.]$//;
	if($line =~ /^(A|C|G|T|N|\.){10}(A|C|G|T|N|\.)+$/) {
	    $line =~ s/\./N/g;
	    print "$line\n";
	} else {
	    die "ERROR: in script parse2fasta.pl: There's only one line in the file '$ARGV[0]' and it doesn't\nlook like sequence.";
	}

	if($paired eq 'true') {
	    print ">seq.1b\n";
            my $infile = open_r($ARGV[1]);
	    my $i=0;
	    $line = <$infile>;
	    until($linearray[$i] == 1) {
		$line = <$infile>;
		$i++;
	    }
	    chomp($line);
	    $line =~ s/[^ACGTN.]$//;
	    if($line =~ /^(A|C|G|T|N|\.){10}(A|C|G|T|N|\.)+$/) {
		$line =~ s/\./N/g;
		print "$line\n";
	    } else {
		die "ERROR: in script parse2fasta.pl: There's only one line in the file '$ARGV[1]' and it doesn't\nlook like sequence.";
	    }
	}
	exit(0);
    }

    # The following finds an arithmetic progression of rows that look like sequence.
    my $k;
    my $i;
    my $j;
    my $flag;
    my $flag2;
    for($k=0; $k<10; $k++) {
	for($i=1; $i<10; $i++) {
	    $flag = 0;
	    $flag2 = 0;
	    for($j=0; $k+$i*$j<@linearray; $j++) {
		my $x = $k+$i*$j;
		if($linearray[$k+$i*$j] == 0) {
		    $flag = 1;
		}
		$flag2 = 1;
	    }
	    if($flag2 == 0) {
		$firstNArow = 0;
		$secondNArow = 0;
	    } else {
		if($flag == 0) {
		    $firstNArow = $k;
		    $secondNArow = $k+$i;
		    $k=10;
		    $i=10;
		}
	    }
	}
	if($k==9 && $flag == 0) {
	    die "\nERROR: in script parse2fasta.pl: canont determine which lines have the sequence.  Consider using\nthe command line options -firstrow and -secondrow.\n\n";
	}
    }
}

# print "firstNArow = $firstNArow\n";
# print "secondNArow = $secondNArow\n";

if($firstNArow == 0 && $secondNArow == 0) {
    print "\nThis does not appear to be a valid file.\n\n";
    exit();
}

my $block = $secondNArow - $firstNArow;

# The number of rows in each block of rows is $block
# The number of the row in each block that has the sequence is $firstNArow

my $linecnt = 0;
$infile1 = open_r($ARGV[0]);
my $infile2 = $paired eq "true" ? open_r($ARGV[1]) : undef;

$cnt = 0;
my $cnt2 = 1;
my $line2;
$linecnt = 0;

while($line = <$infile1>) {    # this loop writes out the fasta file
    if($paired eq "true") {
	$line2 = <$infile2>;
    }
    $linecnt++;
    if((($cnt - $firstNArow) % $block) == 0) {
	print ">seq";
	print ".$cnt2";
	print "a\n";
	chomp($line);
	my $line_hold = $line;
	$line =~ s/[^ACGTN.]$//;
	if($line =~ /[^ACGTN.]/ || !($line =~ /\S/)) {
	    die "There's something wrong with line $linecnt in file $ARGV[0]\nIt should be a line of sequence but it is:\n$line_hold\n\n";
	}
	$line =~ s/\./N/g;
	print "$line\n";
	if($paired eq "true") {
	    print ">seq";
	    print ".$cnt2";
	    print "b\n";
	    $line_hold = $line2;
	    $line2 =~ s/[^ACGTN.]$//;
	    if($line2 =~ /[^ACGTN.]/ || !($line2 =~ /\S/)) {
		print STDERR "\nERROR: in script parse2fasta.pl: There's something wrong with line $linecnt in file $ARGV[1]\nIt should be a line of sequence but it is:\n$line_hold\n\n";
		exit();
	    }
	    $line2 =~ s/\./N/g;
	    print "$line2\n";
	}
	$cnt2++;
    }
    $cnt++;
}

if($linecnt % $block != 0) {
    print STDERR "\nWarning: the last block of lines in file $ARGV[0] is not the right size.\n\n";
}


sub try_to_see_if_part_of_each_line_is_seq () {
    if($paired eq "false") {
	my $infile = open_r($ARGV[0]);
	my $line = <$infile>;
	chomp($line);
	my @a = split(/[^ACGTN.]+/,$line);
	my $maxlen = 0;
	for(my $i=0; $i<@a; $i++) {
	    my $len = length($a[$i]);
	    if($len > $maxlen) {
		$maxlen = $len;
	    }
	}
	
	my $cnt = 0;
	while($line = <$infile>) {
	    chomp($line);
	    $cnt++;
	    my @a = split(/[^ACGTN.]+/,$line);
	    my $flag = 0;
	    for(my $i=0; $i<@a; $i++) {
		my $len = length($a[$i]);
		if($len == $maxlen) {
		    print ">seq.$cnt";
		    $a[$i] =~ s/\./N/g;
		    print "a\n$a[$i]\n";
		    $flag = 1;
		}
	    }
	    if($flag == 0) {
		die "\nERROR: in script parse2fasta.pl: Sorry, can't figure this file out, maybe it's corrupt or you might have to write a custom parser.\n";
	    }
	}
    } else {
        my $infile1 = open_r($ARGV[0]);
        my $infile2 = open_r($ARGV[1]);

	my $line1 = <$infile1>;
	chomp($line1);
	my @a = split(/[^ACGTN.]+/,$line1);
	my $maxlen = 0;
	for(my $i=0; $i<@a; $i++) {
	    my $len = length($a[$i]);
	    if($len > $maxlen) {
		$maxlen = $len;
	    }
	}
	
	my $cnt = 0;
	while($line1 = <$infile1>) {
	    chomp($line1);
	    my $line2 = <$infile2>;
	    chomp($line2);
	    $cnt++;
	    my @a = split(/[^ACGTN.]+/,$line1);
	    my @b = split(/[^ACGTN.]+/,$line2);
	    my $flag1 = 0;
	    for(my $i=0; $i<@a; $i++) {
		my $len = length($a[$i]);
		if($len == $maxlen) {
		    print ">seq.$cnt";
		    $a[$i] =~ s/\./N/g;
		    print "a\n$a[$i]\n";
		    $flag1 = 1;
		}
	    }
	    my $flag2 = 0;
	    for(my $i=0; $i<@a; $i++) {
		my $len = length($a[$i]);
		if($len == $maxlen) {
		    print ">seq.$cnt";
		    $b[$i] =~ s/\./N/g;
		    print "b\n$b[$i]\n";
		    $flag2 = 1;
		}
	    }
	    if($flag1 == 0 || $flag2 == 0) {
		die "\nERROR: in script parse2fasta.pl: Sorry, can't figure these files out, maybe they're corrupt\nor you might have to write a custom parser.\n";
	    }
	}
    }
    my $str = "true";
    return $str;
}
