#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 4;
use FindBin qw($Bin);
use File::Copy;
use lib "$Bin/../lib";
use RUM::Script::LimitNU;
use RUM::TestUtils;

my $in = "$INPUT_DIR/RUM_NU_temp3.1";

for my $limit ((1, 2, 4, 16)) {
    my $out = temp_filename(TEMPLATE => "limit-$limit.XXXXXX");
    @ARGV = ("-q", "-o", $out, "-n", $limit, $in);
    RUM::Script::LimitNU->main();
    no_diffs($out, "$EXPECTED_DIR/RUM_NU-$limit.1");    
}

