#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 3;
use FindBin qw($Bin);
use lib "$Bin/../lib";

use RUM::TestUtils;

use_ok "RUM::Script::GetInferredInternalExons";

my $cov = "$INPUT_DIR/RUM_Unique.cov";
my $junctions = "$INPUT_DIR/junctions_high-quality.bed";
my $out = temp_filename(TEMPLATE => "inferred.XXXXXX");
my $bed_out = temp_filename(TEMPLATE => "inferred-bed.XXXXXX");

our $genes = "_testing/indexes/Arabidopsis_thaliana_TAIR10_ensembl_gene_info.txt";

SKIP: {

    skip "Indexes are not installed", 2 unless -e $genes;

    open my $out_fh, ">", $out or die "Can't open $out for writing: $!";
    
    *STDOUT_BAK = *STDOUT;
    *STDOUT = $out_fh;
    
    @ARGV = ("--junctions", $junctions,
             "--coverage", $cov, 
             "--genes", $genes, 
             "--bed", $bed_out,
             "-q");
    
    RUM::Script::GetInferredInternalExons->main();
    *STDOUT = *STDOUT_BAK;
    close $out_fh;
    
    no_diffs($out, "$EXPECTED_DIR/inferred_internal_exons.txt", 
             "Text format");
    no_diffs($bed_out, "$EXPECTED_DIR/inferred_internal_exons.bed", 
             "Bed format");
}
