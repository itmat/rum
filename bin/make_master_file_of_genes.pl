#!/usr/bin/perl

# Written by Gregory R. Grant
# University of Pennsylvania, 2010

if(@ARGV<1) {
    die "
Usage: make_master_file_of_genes.pl <files file>

This file takes a set of gene annotation files from UCSC and merges them into one.
They have to be downloaded with the following fields:
1) name
2) chrom
3) strand
4) exonStarts
5) exonEnds

This script is part of the pipeline of scripts used to create RUM indexes.
You should probably not be running it alone.  See the library file:
'how2setup_genome-indexes_forPipeline.txt'.

";
}

use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::Index qw(make_master_file_of_genes);

make_master_file_of_genes($ARGV[0]);
