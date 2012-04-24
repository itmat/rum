#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../lib";

use RUM::TestUtils;

my @in = map "$INPUT_DIR/quant.$_", (1, 2);

plan tests => 3;

use_ok("RUM::Script::MergeQuants");
my $out = temp_filename(TEMPLATE => "merge-quants.XXXXXX", UNLINK => 0);
@ARGV = ($INPUT_DIR, "-n", 2, "-o", $out, "-q");

RUM::Script::MergeQuants->main();
no_diffs($out, "$EXPECTED_DIR/feature_quantifications_test");

my $out2 = temp_filename(TEMPLATE => "merge-quants.XXXXXX", UNLINK => 0);
@ARGV = ($INPUT_DIR, "-n", 1, "-o", $out2, "-header", "-q");
RUM::Script::MergeQuants->main();
no_diffs($out2, "$EXPECTED_DIR/novel_exon_quant_temp");
