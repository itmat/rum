#!/usr/bin/perl

# Written by Gregory R. Grant
# University of Pennsylvania, 2010

if(@ARGV < 1) {
    die "
Usage: sort_genome_fa_by_chr.pl <genome fa file>

This script is part of the pipeline of scripts used to create RUM indexes.
You should probably not be running it alone.  See the library file:
'how2setup_genome-indexes_forPipeline.txt'.

";
}

use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::Index qw(transform_input
                  sort_genome_fa_by_chr);

transform_input(\&sort_genome_fa_by_chr);
