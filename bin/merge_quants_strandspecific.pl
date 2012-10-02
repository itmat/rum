#!/usr/bin/perl

# Written by Gregory R Grant
# University of Pennsylvania, 2010

use strict;

if(@ARGV<6) {
    die "
Usage: merge_quants_strandspecific.pl <ps file> <ms file> <pa file> <ma file> <annot file> <outfile>

";
}


my $psfile = $ARGV[0]; 
my $msfile = $ARGV[1]; 
my $pafile = $ARGV[2]; 
my $mafile = $ARGV[3]; 
my $annotfile = $ARGV[4];
my $outfile = $ARGV[5];

for(my $i=6; $i<@ARGV; $i++) {
    my $optionrecognized = 0;
    if($ARGV[$i] eq "XXX") {
	$optionrecognized = 1;
    }
}

my $linecount = 0;
my @strand;
open(INFILE, $annotfile);
while(my $line = <INFILE>) {
    chomp($line);
    my @a = split(/\t/,$line);
    $strand[$linecount] = $a[1];
    $linecount++;
}
my $numtranscripts = $linecount;
close(INFILE);

open(INFILEps, $psfile);
open(INFILEms, $msfile);
open(INFILEpa, $pafile);
open(INFILEma, $mafile);

open(OUTFILE, ">$outfile");

my $line;
my $line1;
my $line2;
my $flag;

$line = <INFILEps>;
$line = <INFILEms>;
$line = <INFILEpa>;
$line = <INFILEma>;

for(my $t=0; $t<$numtranscripts; $t++) {
    $flag = 0;
    while($flag < 3) {
	if($strand[$t] eq '+') {
	    $line1 = <INFILEps>;
	    $line2 = <INFILEpa>;
	} else {
	    $line1 = <INFILEms>;
	    $line2 = <INFILEma>;
	}
	if($line1 =~ /^-+$/ || $line1 eq '') {
	    $flag = 3;
	    next;
	}
	if($flag == 0) {
	    print OUTFILE "--------------------------------------------------------------------\n";
	    print OUTFILE $line1;
	    $flag++;
	    next;
	}
	if($flag == 1) {
	    print OUTFILE "      Type\tLocation           \tmin_sense\tmax_sense\tmin_anti\tmax_anti\tUcount.s\tNUcount.s\tUcount.a\tNUcount.a\tLength\n";
	    $flag++;
	    next;
	}
	chomp($line1);
	chomp($line2);
	my @a1 = split(/\t/,$line1);
	my @a2 = split(/\t/,$line2);
#	print OUTFILE "a:$a1[0]\tb:$a1[1]\tc:$a1[2]\td:$a1[3]\te:$a2[2]\tf:$a2[3]\tg:$a1[4]\n";
	print OUTFILE "$a1[0]\t$a1[1]\t$a1[2]\t$a1[3]\t$a2[2]\t$a2[3]\t$a1[4]\t$a1[5]\t$a2[4]\t$a2[5]\t$a1[6]\n";
    }
}
