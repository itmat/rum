#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 1;
use FindBin qw($Bin);
use File::Copy;
use lib "$Bin/../lib";
use RUM::Script::GetNuStats;
use RUM::TestUtils;

my $out = temp_filename(TEMPLATE => "rum.stats.XXXXXX");

@ARGV = ("$INPUT_DIR/rum.sam", "-o", $out);
RUM::Script::GetNuStats->main();
no_diffs($out, "$EXPECTED_DIR/stats");
