#!/usr/bin/perl

# Written by Gregory R Grant 
# University of Pennsylvania, 2010

$|=1;

if(@ARGV < 5) {
    die "
Usage: make_R.pl <reads file> <bowtie unique file> <bowtie_nu file> <bowtie unmapped outfile> <type>

Where:  <reads file> is the fasta file of reads

        <bowtie unique file> the file of unique mappers output from merge_GU_and_TU.pl

        <bowtie nu file> the file of non-unique mappers output from merge_GNU_and_TNU_and_CNU.pl

        <type> is 'single' for single-end reads, or 'paired' for paired-end reads

        <bowtie unmapped outfile> is the name of the file of unmapped reads to be output.

";
}

# FIX THIS SO THAT READS CAN SPAN MORE THAN ONE LINE IN THE FASTA FILE
$infile = $ARGV[0];
$infile1 = $ARGV[1];
$infile2 = $ARGV[2];
$outfile = $ARGV[3];
$type = $ARGV[4];
$typerecognized = 1;
if($type eq "single") {
    $paired_end = "false";
    $typerecognized = 0;
}
if($type eq "paired") {
    $paired_end = "true";
    $typerecognized = 0;
}
if($typerecognized == 1) {
    die "\nERROR: type '$type' not recognized.  Must be 'single' or 'paired'.\n";
}

open(INFILE, $infile1) or die "\nERROR: Cannot open file '$infile1' for reading\n";
while($line = <INFILE>) {
    chomp($line);
    $line =~ s/\t.*//;
    if(!($line =~ /(a|b)/)) {
	$bu{$line}=2;
    }
    else {
	$line =~ s/(a|b)//;
	$bu{$line}++;
    }
}
close(INFILE);

open(INFILE, $infile2) or die "\nERROR: Cannot open file '$infile2' for reading\n";
while($line = <INFILE>) {
    chomp($line);
    $line =~ s/\t.*//;
    $line =~ s/(a|b)//;
    $bnu{$line}++;
}
close(INFILE);

open(INFILE, $infile) or die "\nERROR: Cannot open file '$infile' for reading\n";

open(OUTFILE, ">$outfile") or die "\nERROR: Cannot open file '$outfile' for writing\n";

while($line = <INFILE>) {
    chomp($line);
    if($line =~ /^>(seq.\d+)/) {
	$seq = $1;
	if($paired_end eq "true") {
	    if($bu{$seq}+0 < 2 && !($bnu{$seq} =~ /\S/)) {
		print OUTFILE "$line\n";
		$line = <INFILE>;
		print OUTFILE $line;
		$line = <INFILE>;
		print OUTFILE $line;
		$line = <INFILE>;
		print OUTFILE $line;
	    }
	}
	else {
	    if($bu{$seq}+0 < 1 && !($bnu{$seq} =~ /\S/)) {
		print OUTFILE "$line\n";
		$line = <INFILE>;
		print OUTFILE $line;
	    }
	}
    }
}
close(INFILE);
close(OUTFILE);

print STDERR "Starting BLAT on '$outfile'.\n";
