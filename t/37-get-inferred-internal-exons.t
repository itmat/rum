#!/usr/bin/env perl

use strict;
use warnings;

use Test::More test => 2;
use FindBin qw($Bin);
use lib "$Bin/../lib";

use RUM::TestUtils;

my $cov = "$INPUT_DIR/RUM_Unique.cov";
my $junctions = "$INPUT_DIR/junctions_high-quality.bed";
my $out = temp_filename(TEMPLATE => "inferred.XXXXXX");
my $bed_out = temp_filename(TEMPLATE => "inferred-bed.XXXXXX");

our $genes = "_testing/indexes/Arabidopsis_thaliana_TAIR10_ensembl_gene_info.txt";

system "perl $Bin/../bin/get_inferred_internal_exons.pl $junctions $cov $genes -bed $bed_out > $out";

no_diffs($out, "$EXPECTED_DIR/inferred_internal_exons.txt", 
         "Text format");
no_diffs($bed_out, "$EXPECTED_DIR/inferred_internal_exons.bed", 
         "Bed format");

