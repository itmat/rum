#!/usr/bin/perl

# Written by Gregory R. Grant
# University of Pennsylvania, 2010

if(@ARGV < 1) {
    die "
Usage: modify_fasta_header_for_genome_seq_database.pl <fasta file>

This expects a fasta file with header that looks like:
>hg19_ct_UserTrack_3545_+ range=chrUn_gl000248:1-39786 5'pad=0 3'pad=0 strand=+ repeatMasking=none
and it modifies it to look like this:
>chrUn_gl000248

This script is part of the pipeline of scripts used to create RUM indexes.
You should probably not be running it alone.  See the library file:
'how2setup_genome-indexes_forPipeline.txt'.

";
}

open(INFILE, $ARGV[0]);

while($line = <INFILE>) {
    chomp($line);
    if($line =~ /^>/) {
	$line =~ s/^>//;
        $line =~ s/.*UserTrack_3545_.*range=//;
        $line =~ s/ 5'pad=0 3'pad=0//;
        $line =~ s/ repeatMasking=none//;
        $line =~ s/ /_/g;
	$line =~ s/:[^:]+$//;
        $line = ">" . $line;
    }
    print "$line\n";
}
