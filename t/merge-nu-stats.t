#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 2;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use_ok("RUM::Script::MergeNuStats");
use RUM::TestUtils;

my $out = temp_filename(TEMPLATE => "merged-nu-stats.XXXXXX", UNLINK => 0);

my $out_fh;
open $out_fh, ">", $out;
*OLD = *STDOUT;
*STDOUT = $out_fh;
@ARGV = map { "$INPUT_DIR/nu_stats.$_" } (1, 2);
RUM::Script::MergeNuStats->main();
*STDOUT = *OLD;
no_diffs($out, "$EXPECTED_DIR/merged");

