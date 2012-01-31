#!/usr/bin/perl

# Written by Gregory R Grant 
# University of Pennsylvania, 2010

# NOTE: add something to check if it's a fasta file with seq spanning
# multiple lines, this case is otherwise not being handled.

$|=1;
use strict;

my $n = @ARGV;
if(@ARGV < 1) {
    print "\nUsage: parse2fasta.pl <infile1> [infile2] [options]\n\n";
    print "infile1 are the forward reads and infile2 are the reverse (if there are\nreverse reads).\n\n";
    print "Options:\n";
    print "     -firstrow n  : n is the first row that has sequence on it.\n";
    print "     -secondrow n : n is the second row that has sequence on it.\n\n";
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
if(-e $ARGV[1]) {
    $optionsstart = 2;
    $paired = "true";
} else {
    $optionsstart = 1;
}

my $firstNArow = 0;
my $secondNArow = 0;
my $userparamsgiven = 0;
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
    if($optionrecognized == 1) {
	die "\nERROR: in script fastq2qualities.pl: option '$ARGV[$i-1]' not recognized.  Must be 'single' or 'paired'.\n";
    }
}
if(($firstNArow =~ /\S/ && !($secondNArow =~ /\S/)) && ($secondNArow =~ /\S/ && !($firstNArow =~ /\S/))) {
    die "\nERROR: in script fastq2qualities.pl: you must set *both* -firstrow and -secondrow, or neither\n";
}

my $standard = "true";
open(INFILE, $ARGV[0]);
for(my $i=0; $i<1000; $i++) {
    my $line = <INFILE>;
    chomp($line);
    if($line eq '') {
        if($i < 4) {
            $standard = "false";
        }
	$i = 1000;
    } else  {
	if(!($line =~ /^@/)) {
	    $standard = "false";
	}
	$line = <INFILE>;
	chomp($line);
	if(!($line =~ /^[ACGTN.]+$/)) {
	    $standard = "false";
	}
	$line = <INFILE>;
	chomp($line);
	if(!($line =~ /^\+/)) {
	    $standard = "false";
	}
	$line = <INFILE>;
	chomp($line);
	if(!($line =~ /^[!-~]+$/)) {
	    $standard = "false";
	}
    }
}
close(INFILE);

if($standard eq 'true') {
    $firstNArow = 3;
    $secondNArow = 7;
} else {
    if($userparamsgiven == 0) {
	print "\nSorry, can't figure these files out, doesn't look like fastq...\n";
	exit(0);
    }
}

# print "firstNArow = $firstNArow\n";
# print "secondNArow = $secondNArow\n";

my $block = $secondNArow - $firstNArow;

# The number of rows in each block of rows is $block
# The number of the row in each block that has the sequence is $firstNArow

my $linecnt = 0;
open(INFILE1, $ARGV[0]);
if($paired eq "true") {
    open(INFILE2, $ARGV[1]);
}
my $cnt = 0;
my $cnt2 = 1;
my $line2;
$linecnt = 0;

while(my $line = <INFILE1>) {    # this loop writes out the fasta file
    if($paired eq "true") {
	$line2 = <INFILE2>;
	chomp($line2);
    }
    $linecnt++;
    if((($cnt - $firstNArow) % $block) == 0) {
	print ">seq";
	print ".$cnt2";
	print "a\n";
	chomp($line);
	my $line_hold = $line;
	if(($line =~ /[^!-~]/ || !($line =~ /\S/))) {
	    print STDERR"\nWARNING: in script fastq2qualities.pl: There seems to be something wrong with line $linecnt in file $ARGV[0]\nIt should be a line of quality scores but it is:\n$line_hold\n\n";
	    print "\nWARNING: There seems to be something wrong with line $linecnt in file $ARGV[0]\nIt should be a line of quality scores but it is:\n$line_hold\n\n";
	    print "\nSorry, can't figure these files out, maybe they're not fastq, they're corrupt, or you might have to write a custom parser.\n";
	    exit();
	}
	print "$line\n";
	if($paired eq "true") {
	    print ">seq";
	    print ".$cnt2";
	    print "b\n";
	    $line_hold = $line2;
	    if(($line2 =~ /[^!-~]/ || !($line2 =~ /\S/))) {
		print STDERR "\nWARNING: in fastq2qualities.pl: There's something wrong with line $linecnt in file $ARGV[1]\nIt should be a line of quality scores but it is:\n$line_hold\n\n";
		print "\nWARNING: There's something wrong with line $linecnt in file $ARGV[1]\nIt should be a line of quality scores but it is:\n$line_hold\n\n";
		print "\nSorry, can't figure these files out, maybe they're not fastq, they're corrupt, or you might have to write a custom parser.\n";
		exit();
	    }
	    print "$line2\n";
	}
	$cnt2++;
    }
    $cnt++;
}
close(INFILE1);
close(INFILE2);
if($linecnt % $block != 0) {
    print STDERR "\nWarning: in script fastq2qualities.pl: the last block of lines in file $ARGV[0] is not the right size.\n\n";
}
