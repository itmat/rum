#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 2;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use_ok("RUM::Script::CountReadsMapped");
use RUM::TestUtils;

my $unique     = "$SHARED_INPUT_DIR/RUM_Unique.sorted.1";
my $non_unique = "$SHARED_INPUT_DIR/RUM_NU.sorted.1";

my $out = temp_filename(TEMPLATE => "reads-mapped.XXXXXX", UNLINK => 0);

my $out_fh;
open $out_fh, ">", $out;
*OLD = *STDOUT;
*STDOUT = $out_fh;
@ARGV = (
    "--unique-in", $unique, 
    "--non-unique-in", $non_unique,
    "--min", 1,
    "--max", 1000);
RUM::Script::CountReadsMapped->main();
*STDOUT = *OLD;
close $out_fh;

no_diffs($out, "$EXPECTED_DIR/reads-mapped");

