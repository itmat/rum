#!/usr/bin/perl

use strict;
use warnings;
use autodie;

use FindBin qw($Bin);
use lib ("$Bin/../lib", "$Bin/../lib/perl5");
use RUM::Common qw(open_r);

use File::Spec;

if(@ARGV<3) {
    die "
Usage: parsefasta.pl <infile> <num chunks> <reads out> [option]

option:
          -name_mapping F  : If set will write a file <F> mapping modified names to
                             original names

";
}

my $infile = $ARGV[0];
my $numchunks = $ARGV[1];
my $reads_out = $ARGV[2];

my $name_mapping_file;
my $map_names = "false";
my $optionrecognized;
for(my $i=3; $i<@ARGV; $i++) {
    $optionrecognized = 0;
    if($ARGV[$i] eq "-name_mapping") {
	$map_names = "true";
	$i++;
	$name_mapping_file = $ARGV[$i];
	open(NAMEMAPPINGALL, ">$name_mapping_file");
	$optionrecognized = 1;
    }
    if($optionrecognized == 0) {
	die "\nERROR: option $ARGV[$i] not recognized.\n\n";
    }
}

my $paired = "true";
my $infile1;
my $infile2;
my $name_mapping_chunk;
my $readname;

if($infile =~ /,,,/) {
    $infile =~ /^(.*),,,(.*)$/;
    $infile1 = $1;
    $infile2 = $2
} else {
    $infile1 = $infile;
    $paired = "false";
}
my $INFILE1 = open_r($infile1);
my $INFILE2 = $paired eq "true" ? open_r($infile2) : undef;

my $filesize = -s $infile1;

# put something here for the case the file is less than 10,000 lines (or 2,500 entries)

my $FL = `head -10000 $infile1 | wc -l`;
chomp($FL);
$FL =~ s/[^\d]//gs;

my $s1 = `head -$FL $infile1`;
my $s2 = `tail -$FL $infile1`;
my $totalsize = length($s1) + length($s2);
my $recordsize = $totalsize / $FL;
my $numrecords = int($filesize / $recordsize);
my $numrecords_per_chunk = int($numrecords / $numchunks);

sub in_chunk_dir {
    my $filename = shift;

    my (undef, $dir, $file) = File::Spec->splitpath($filename);
    return File::Spec->catfile($dir, "chunks", $file);
}


my $seq_counter = 0;
my $endflag = 0;
open(ROUTALL, ">$reads_out");
if($paired eq "false") {
    for(my $chunk=1; $chunk<=$numchunks; $chunk++) {
	my $reads_file = in_chunk_dir($reads_out) . ".$chunk";
	if($endflag == 1) {
	    $chunk = $numchunks;
	    next;
	}
	open(ROUT, ">$reads_file");
	if($map_names eq "true") {
	    $name_mapping_chunk = $name_mapping_file . ".$chunk";
	    open(NAMEMAPPING, ">$name_mapping_chunk");
	}
	if($chunk == $numchunks) {
	    # just to make sure we get everything in the last chunk
	    $numrecords_per_chunk = $numrecords_per_chunk * 100; 
	}
	for(my $i=0; $i<$numrecords_per_chunk; $i++) {
	    $seq_counter++;
	    my $line = <$INFILE1>;
	    chomp($line);
	    $readname = $line;
	    $readname =~ s/^>//;
	    my $line_hold = $line;
	    $line = <$INFILE1>;
	    chomp($line);
	    if($line eq '' && $line_hold ne '') {
		print STDERR "ERROR: in script parsefasta.pl: something is wrong, the file seems to end with an incomplete record...\n";
		exit(0);
	    }
	    if($line eq '') {
		$i = $numrecords_per_chunk;
		$endflag = 1;
		next;
	    }
	    print ROUT ">seq.$seq_counter";
	    print ROUTALL ">seq.$seq_counter";
	    print ROUT "a\n";
	    print ROUTALL "a\n";
	    $line =~ s/\./N/g;
	    $line = uc $line;
	    print ROUT "$line\n";
	    print ROUTALL "$line\n";
	    if($map_names eq "true") {
		print NAMEMAPPINGALL "seq.$seq_counter";
		print NAMEMAPPINGALL "a\t$readname\n";
		print NAMEMAPPING "seq.$seq_counter";
		print NAMEMAPPING "a\t$readname\n";
	    }
	}
	close(ROUT);
	if($map_names eq "true") {
	    close(NAMEMAPPING);
	}
    }
}

if($paired eq "true") {
    for(my $chunk=1; $chunk<=$numchunks; $chunk++) {
	my $reads_file = in_chunk_dir($reads_out) . ".$chunk";

	if($endflag == 1) {
	    $chunk = $numchunks;
	    next;
	}
	open(ROUT, ">$reads_file");
	if($map_names eq "true") {
	    $name_mapping_chunk = $name_mapping_file . ".$chunk";
	    open(NAMEMAPPING, ">$name_mapping_chunk");
	}
	if($chunk == $numchunks) {
	    # just to make sure we get everything in the last chunk
	    $numrecords_per_chunk = $numrecords_per_chunk * 100; 
	}
	for(my $i=0; $i<$numrecords_per_chunk; $i++) {
	    $seq_counter++;
	    my $line = <$INFILE1>;
            last if ! defined $line;
	    $readname = $line;
	    $readname =~ s/^>//;
	    my $line_hold = $line;
	    $line = <$INFILE1>;
	    chomp($line);
	    if($line eq '' && $line_hold ne '') {
		print STDERR "ERROR: in script parsefasta.pl: something is wrong, the forward file seems to end with an incomplete record...\n";
		exit(0);
	    }
	    if($line eq '') {
		$i = $numrecords_per_chunk;
		$endflag = 1;
		next;
	    }
	    print ROUT ">seq.$seq_counter";
	    print ROUTALL ">seq.$seq_counter";
	    print ROUT "a\n";
	    print ROUTALL "a\n";
	    $line =~ s/\./N/g;
	    $line = uc $line;
	    print ROUT "$line\n";
	    print ROUTALL "$line\n";
	    if($map_names eq "true") {
		print NAMEMAPPINGALL "seq.$seq_counter";
		print NAMEMAPPINGALL "a\t$readname\n";
		print NAMEMAPPING "seq.$seq_counter";
		print NAMEMAPPING "a\t$readname\n";
	    }
	    $line = <$INFILE2>;
	    chomp($line);
	    $readname = $line;
	    $readname =~ s/^>//;
	    $line_hold = $line;
	    $line = <$INFILE2>;
	    chomp($line);
	    if($line eq '' && $line_hold ne '') {
		$i = $numrecords_per_chunk;
		print STDERR "ERROR: in script parsefasta.pl: something is wrong, the reverse file seems to end with an incomplete record...\n";
		exit(0);
	    }
	    print ROUT ">seq.$seq_counter";
	    print ROUTALL ">seq.$seq_counter";
	    print ROUT "b\n";
	    print ROUTALL "b\n";
	    $line =~ s/\./N/g;
	    print ROUT "$line\n";
	    print ROUTALL "$line\n";
	    if($map_names eq "true") {
		print NAMEMAPPINGALL "seq.$seq_counter";
		print NAMEMAPPINGALL "b\t$readname\n";
		print NAMEMAPPING "seq.$seq_counter";
     		print NAMEMAPPING "b\t$readname\n";
	    }
	}
	close(ROUT);
	if($map_names eq "true") {
	    close(NAMEMAPPING);
	}
    }
}

close(ROUTALL);
