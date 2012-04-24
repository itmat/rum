#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 4;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::Script::MakeTuAndTnu;
use RUM::TestUtils;

my $gene_info = $RUM::TestUtils::GENE_INFO;

SKIP: {
    skip "Don't have arabidopsis index", 4 unless -e $gene_info;
    for my $type (qw(paired single)) {

        my $u  = temp_filename(
            TEMPLATE => "transcriptome-$type-unique.XXXXXX");
        my $nu = temp_filename(
            TEMPLATE => "transcriptome-$type-non-unique.XXXXXX");

        @ARGV = ("--bowtie", "$INPUT_DIR/Y.1",
                 "--genes", $gene_info,
                 "--unique", $u, 
                 "--non-unique", $nu, 
                 "--$type", "-q");
        
        RUM::Script::MakeTuAndTnu->main();

        no_diffs($u, "$EXPECTED_DIR/transcriptome-$type-unique",
                 "$type unique");
        no_diffs($nu, "$EXPECTED_DIR/transcriptome-$type-non-unique",
                 "$type non-unique");
    }
}
