#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 2;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use_ok("RUM::Script::MergeChrCounts");
use RUM::TestUtils;

my $out = temp_filename(TEMPLATE => "merged-chr-counts.XXXXXX", UNLINK => 0);

@ARGV = ("-o", $out, "$INPUT_DIR/chr_counts_u.1", "$INPUT_DIR/chr_counts_u.2");
RUM::Script::MergeChrCounts->main();
no_diffs($out, "$EXPECTED_DIR/merged");

