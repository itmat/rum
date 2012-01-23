#!/usr/bin/perl

# Written by Gregory R. Grant
# Universiry of Pennsylvania, 2010

if(@ARGV < 1) {
    die "
Usage: fix_geneinfofile_for_neg_introns.pl <gene info file> <starts col> <ends col> <num exons col>

This script takes a UCSC gene annotation file and outputs a file that removes
introns of zero or negative length.  You'd think there shouldn't be such introns
but for some annotation sets there are.

<starts col> is the column with the exon starts, <ends col> is the column with
the exon ends.  These are counted starting from zero.  <num exons col> is the
column that has the number of exons, also counted starting from zero.  If there
is no such column, set this to -1.

This script is part of the pipeline of scripts used to create RUM indexes.
For more information see the library file: 'how2setup_genome-indexes_forPipeline.txt'.

";
}

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::Index qw(transform_input
                  fix_geneinfofile_for_neg_introns);

print "Starting\n";

transform_input(\&fix_geneinfofile_for_neg_introns, @ARGV[1,2,3]);
print "Hre!\n";

