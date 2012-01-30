#!/usr/bin/perl

# Written by Gregory R. Grant
# University of Pennsylvania, 2010

$|=1;

if(@ARGV < 4) {
    die "
Usage: merge_GNU_and_TNU_and_CNU.pl <GNU infile> <TNU infile> <CNU infile> <Bowtie NU outfile>

Where:  <GNU infile> is the file of non-unique mappers from the script make_GU_and_GNU.pl
        <TNU infile> is the file of non-unique mappers from the script make_TU_and_TNU.pl
        <CNU infile> is the file of non-unique mappers from the script merge_GU_and_TU.pl
        <Bowtie NU outfile> is the name of the file of non-unique mappers to be output.

";
}

$infile1 = $ARGV[0];
open(INFILE1, $infile1) or die "\nERROR: Cannot open file '$infile1' for reading\n";
$infile2 = $ARGV[1];
open(INFILE2, $infile2) or die "\nERROR: Cannot open file '$infile2' for reading\n";
$infile3 = $ARGV[2];
open(INFILE3, $infile3) or die "\nERROR: Cannot open file '$infile3' for reading\n";
$x1 = `tail -1 $infile1`;
$x2 = `tail -1 $infile2`;
$x3 = `tail -1 $infile3`;
$x1 =~ /seq.(\d+)[^\d]/;
$n1 = $1;
$x2 =~ /seq.(\d+)[^\d]/;
$n2 = $1;
$x3 =~ /seq.(\d+)[^\d]/;
$n3 = $1;
$M = $n1;
if($n2 > $M) {
    $M = $n2;
}
if($n3 > $M) {
    $M = $n3;
}
$line1 = <INFILE1>;
$line2 = <INFILE2>;
$line3 = <INFILE3>;
chomp($line1);
chomp($line2);
chomp($line3);
$outfile = $ARGV[3];
open(OUTFILE, ">$outfile") or die "\nERROR: Cannot open file '$outfile' for writing\n";
for($s=1; $s<=$M; $s++) {
    undef %hash;
    $line1 =~ /seq.(\d+)([^\d])/;
    $n = $1;
    $type = $2;
    while($n == $s) {
	if($type eq "\t") {
	    $hash{$line1}++;
	}
	else {
	    $line1b = <INFILE1>;
	    chomp($line1b);
	    if($line1b eq '') {
		last;
	    }
	    $hash{"$line1\n$line1b"}++;
	}
	$line1 = <INFILE1>;
	chomp($line1);
	if($line1 eq '') {
	    last;
	}
	$line1 =~ /seq.(\d+)([^\d])/;
	$n = $1;
	$type = $2;
    }
    $line2 =~ /seq.(\d+)([^\d])/;
    $n = $1;
    $type = $2;
    while($n == $s) {
	if($type eq "\t") {
	    $hash{$line2}++;
	}
	else {
	    $line2b = <INFILE2>;
	    chomp($line2b);
	    if($line2b eq '') {
		last;
	    }
	    $hash{"$line2\n$line2b"}++;
	}
	$line2 = <INFILE2>;
	chomp($line2);
	if($line2 eq '') {
	    last;
	}
	$line2 =~ /seq.(\d+)([^\d])/;
	$n = $1;
	$type = $2;
    }
    $line3 =~ /seq.(\d+)([^\d])/;
    $n = $1;
    $type = $2;
    while($n == $s) {
	if($type eq "\t") {
	    $hash{$line3}++;
	}
	else {
	    $line3b = <INFILE3>;
	    chomp($line3b);
	    if($line3b eq '') {
		last;
	    }
	    $hash{"$line3\n$line3b"}++;
	}
	$line3 = <INFILE3>;
	chomp($line3);
	if($line3 eq '') {
	    last;
	}
	$line3 =~ /seq.(\d+)([^\d])/;
	$n = $1;
	$type = $2;
    }
    for $key (keys %hash) {
	if($key =~ /\S/) {
	    print OUTFILE "$key\n";
	}
    }
}

close(INFILE1);
close(INFILE2);
close(INFILE3);
