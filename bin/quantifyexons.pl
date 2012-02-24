#!/usr/bin/perl

# Written by Gregory R Grant
# University of Pennsylvania, 2010

$|=1;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use RUM::Common qw(roman Roman isroman arabic);
use RUM::Sort qw(cmpChrs);

use strict;

if(@ARGV < 4) {
    die "
Usage: quantifyexons.pl <exons file> <RUM_Unique> <RUM_NU> <outfile> [options]

Where:

    <exons file> is a list of exons in format chr:start-end, one per line

    <RUM_Unique> is the sorted RUM Unique file

    <RUM_NU> is the sorted RUM NU file

    <outfile> the file to write the results to

Options:

    -sepout filename : Make separate files for the min and max experssion values.
                       In this case will write the min values to <outfile> and the   
                       max values to the file specified by 'filename'.
                       There are two extra columns in each file if done this way,
                       one giving the raw count and one giving the count normalized
                       only by the feature length.

    -posonly  :  Output results only for transcripts that have non-zero intensity.
                 Note: if using -sepout, this will output results to both files for
                 a transcript if either one of the unique or non-unique counts is zero.

    -countsonly :  Output only a simple file with feature names and counts.

    -strand s : s=p to use just + strand reads, s=m to use just - strand.

    -info f   : f is a file that maps gene id's to info (i.e. annotation or other gene ids).
                f must be tab delmited with the first column of known ids and second
                column of annotation.

    -anti     : Use in conjunction with -strand to record anti-sense transcripts instead
                of sense. 

";
}

my $annotfile = $ARGV[0];
my $U_readsfile = $ARGV[1];
my $NU_readsfile = $ARGV[2];
my $outfile1 = $ARGV[3];
my $outfile2;

my %EXON_temp;
my %cnt;
my @A;
my @B;
my %ecnt;
my %NUREADS;
my $UREADS=0;

my $sepout = "false";
my $posonly = "false";
my $countsonly = "false";
my $strandspecific="false";
my $strand = "";
my $anti = "false";
my $infofile;
my $infofile_given = "false";
for(my $i=4; $i<@ARGV; $i++) {
    my $optionrecognized = 0;
    if($ARGV[$i] eq "-sepout") {
	$sepout = "true";
	$outfile2 = $ARGV[$i+1];
	$i++;
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-info") {
	$infofile_given = "true";
        $i++;
        $infofile = $ARGV[$i];
        if(!(-e $infofile)) {
            die "ERROR: in script rum2quantifications.pl: info file '$infofile' does not seem to exist.\n\n";
        }
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-strand") {
	$strand = $ARGV[$i+1];
	$strandspecific="true";
	$i++;
	if(!($strand eq 'p' || $strand eq 'm')) {
	    die "\nERROR: in script rum2quantifications.pl: -strand must equal either 'p' or 'm', not '$strand'\n\n";
	}
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-posonly") {
	$posonly = "true";
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-anti") {
	$anti = "true";
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-countsonly") {
	$countsonly = "true";
	$optionrecognized = 1;
    }
    if($optionrecognized == 0) {
	die "\nERROR: in script rum2quantifications.pl: option '$ARGV[$i]' not recognized\n";
    }
}

# read in the info file, if given

my %INFO;
if($infofile_given eq "true") {
    open(INFILE, $infofile) or die "ERROR: in script rum2quantifications.pl: Cannot open the file '$infofile' for reading\n";
    while(my $line = <INFILE>) {
	chomp($line);
	my @a = split(/\t/,$line);
	$INFO{$a[0]} = $a[1];
    }
    close(INFILE);
}

# read in the transcript models

open(INFILE, $annotfile) or die "ERROR: in script rum2quantifications.pl: cannot open '$annotfile' for reading.\n\n";
my %EXON;
my %CHRS;
while(my $line = <INFILE>) {
    chomp($line);
    my @a = split(/\t/,$line);
    my $STRAND = $a[1];
    if($strandspecific eq 'true') {
	if($strand =~ /^p/ && $a[1] eq '-') {
	    next;
	}
	if($strand =~ /^m/ && $a[1] eq '+') {
	    next;
	}
    }
    $a[0] =~ /^(.*):(\d+)-(\d+)$/;
    my $chr = $1;
    my $start = $2;
    my $end = $3;
    if($CHRS{$chr}+0==0) {
	$ecnt{$chr} = 0;
	$CHRS{$chr}=1;
    }
    $EXON{$chr}[$ecnt{$chr}]{start} = $start;
    $EXON{$chr}[$ecnt{$chr}]{end} = $end;
    $ecnt{$chr}++;
}

&readfile($U_readsfile, "Ucount");
&readfile($NU_readsfile, "NUcount");

my %EXONhash;
open(OUTFILE1, ">$outfile1") or die "ERROR: in script rum2quantifications.pl: cannot open file '$outfile1' for writing.\n\n";
my $num_reads = $UREADS;
$num_reads = $num_reads + (scalar keys %NUREADS);
if($countsonly eq "true") {
    print OUTFILE1 "num_reads = $num_reads\n";
}
foreach my $chr (sort {cmpChrs($a,$b)} keys %EXON) {
    for(my $i=0; $i<$ecnt{$chr}; $i++) {
	my $x1 = $EXON{$chr}[$i]{Ucount}+0;
	my $x2 = $EXON{$chr}[$i]{NUcount}+0;
	my $s = $EXON{$chr}[$i]{start};
	my $e = $EXON{$chr}[$i]{end};
	my $elen = $e - $s + 1;
	print OUTFILE1 "exon\t$chr:$s-$e\t$x1\t$x2\t$elen\n";
    }
}

sub readfile () {
    my ($filename, $type) = @_;
    open(INFILE, $filename) or die "ERROR: in script rum2quantifications.pl: cannot open '$filename' for reading.\n\n";
    my %HASH;
    my $counter=0;
    my $line;
    my %indexstart_t;
    my %indexstart_e;
    my %indexstart_i;
    foreach my $chr (keys %EXON) {
	$indexstart_e{$chr} = 0;
    }
    while($line = <INFILE>) {
	$counter++;
	if($counter % 100000 == 0 && $countsonly eq "false") {
	    print "$type: counter=$counter\n";
	}
	chomp($line);
	if($line eq '') {
	    last;
	}
	my @a = split(/\t/,$line);
	my $STRAND = $a[3];
	$a[0] =~ /(\d+)/;
	my $seqnum1 = $1;
	if($type eq "NUcount") {
	    $NUREADS{$seqnum1}=1;
	} else {
	    $UREADS++;
	}
	if($strandspecific eq 'true') {
	    if($strand eq 'p' && $STRAND eq '-' && $anti eq 'false') {
		next;
	    }
	    if($strand eq 'm' && $STRAND eq '+' && $anti eq 'false') {
		next;
	    }
	    if($strand eq 'p' && $STRAND eq '+' && $anti eq 'true') {
		next;
	    }
	    if($strand eq 'm' && $STRAND eq '-' && $anti eq 'true') {
		next;
	    }
	}
	my $CHR = $a[1];
	$HASH{$CHR}++;
#	if($HASH{$CHR} == 1) {
#	    print "CHR: $CHR\n";
#	}
	$a[2] =~ /^(\d+)-/;
	my $start = $1;
	my $end;
	my $line2 = <INFILE>;
	chomp($line2);
	my @b = split(/\t/,$line2);
	$b[0] =~ /(\d+)/;
	my $seqnum2 = $1;
	my $spans_union;
	
	if($seqnum1 == $seqnum2 && $b[0] =~ /b/ && $a[0] =~ /a/) {
	    my $SPANS;
	    if($a[3] eq "+") {
		$b[2] =~ /-(\d+)$/;
		$end = $1;
		$SPANS = $a[2] . ", " . $b[2];
	    } else {
		$b[2] =~ /^(\d+)-/;
		$start = $1;
		$a[2] =~ /-(\d+)$/;
		$end = $1;
		$SPANS = $b[2] . ", " . $a[2];
	    }
#	    my $SPANS = &union($a[2], $b[2]);
 	    @B = split(/[^\d]+/,$SPANS);
 	} else {
	    $a[2] =~ /-(\d+)$/;
	    $end = $1;
	    # reset the file handle so the last line read will be read again
	    my $len = -1 * (1 + length($line2));
	    seek(INFILE, $len, 1);
	    @B = split(/[^\d]+/,$a[2]);
	}
	while($EXON{$CHR}[$indexstart_e{$CHR}]{end} < $start && $indexstart_e{$CHR} <= $ecnt{$CHR}) {
	    $indexstart_e{$CHR}++;	
	}
	my $i = $indexstart_e{$CHR};
	my $flag = 0;
	while($flag == 0) {
	    $ecnt{$CHR} = $ecnt{$CHR}+0;
	    if($end < $EXON{$CHR}[$i]{start} || $i >= $ecnt{$CHR}) {
		last;
	    }
	    undef @A;
	    $A[0] = $EXON{$CHR}[$i]{start};
	    $A[1] = $EXON{$CHR}[$i]{end};
	    my $b = &do_they_overlap();
	    if($b == 1) {
		$EXON{$CHR}[$i]{$type}++;
	    }
	    $i++;
	}
    }
}

sub do_they_overlap() {
    # going to pass in two arrays as global vars, because don't want them
    # to be copied every time, this function is going to be called a lot.
    # the global vars @A and @B

    my $i=0;
    my $j=0;

    while(1==1) {
	until(($B[$j] < $A[$i] && $i%2==0) || ($B[$j] <= $A[$i] && $i%2==1)) {
	    $i++;
	    if($i == @A) {
		if($B[$j] == $A[@A-1]) {
		    return 1;
		} else {
		    return 0;
		}
	    }
	}
	if(($i-1) % 2 == 0) {
	    return 1;
	} else {
	    $j++;
	    if($j%2==1 && $A[$i] <= $B[$j]) {
		return 1;
	    }
	    if($j >= @B) {
		return 0;
	    }
	}
    }
}


sub union () {
    my ($spans1_u, $spans2_u) = @_;

    my %chash;
    my @a = split(/, /,$spans1_u);
    for(my $i=0;$i<@a;$i++) {
	my @b = split(/-/,$a[$i]);
	for(my $j=$b[0];$j<=$b[1];$j++) {
	    $chash{$j}++;
	}
    }
    @a = split(/, /,$spans2_u);
    for(my $i=0;$i<@a;$i++) {
	my @b = split(/-/,$a[$i]);
	for(my $j=$b[0];$j<=$b[1];$j++) {
	    $chash{$j}++;
	}
    }
    my $first = 1;
    my $spans_union;
    my $pos_prev;
    foreach my $pos (sort {$a<=>$b} keys %chash) {
	if($first == 1) {
	    $spans_union = $pos;
	    $first = 0;
	} else {
	    if($pos > $pos_prev + 1) {
		$spans_union = $spans_union . "-$pos_prev, $pos";
	    }
	}
	$pos_prev = $pos;
    }
    $spans_union = $spans_union . "-$pos_prev";
    return $spans_union;
}

# seq.35669       chr1    3206742-3206966 -       GCCCACCACCATGTCAAACACAATCTCTTCCCATTTGGTGATACAGAATTCTGTCTCACAGTGGACAATCCAGAAAGTCATGATGCACCAATGGAGGACAATAAATATCCCAAAATACAGCTGGAAAACCGAGGCAAAGAGGGCGAATGTGATGACCCTGGCAGCGATGGTGAAGAAATGCCAGCAGAACTGAATGATGACAGCCATTTAGCTGATGGGCTTTTT
# 
# 
# chr1    -       3195981 3206425 2       3195981,3203689,        3197398,3206425,        OTTMUST00000086625(vega)
