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
my $cmd = "perl $Bin/../bin/count_reads_mapped.pl $unique $non_unique -minseq 1 -maxseq 1000 > $out";
diag "Running $cmd";
system $cmd;
no_diffs($out, "$EXPECTED_DIR/reads-mapped");

