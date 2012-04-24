#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 1;
use FindBin qw($Bin);
use File::Copy;
use lib "$Bin/../lib";
use RUM::Script::SortRumById;
use RUM::TestUtils;

my $in = "$INPUT_DIR/RUM_Unique_temp2.1";
my $out = temp_filename(TEMPLATE => "id-sorted.XXXXXX");

@ARGV = ($in, "-o", $out, "-q");
RUM::Script::SortRumById->main();

no_diffs($out, "$EXPECTED_DIR/RUM_Unique_idsorted.1");

