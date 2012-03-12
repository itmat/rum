#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 6;
use FindBin qw($Bin);
use File::Copy;
use lib "$Bin/../lib";
use RUM::Script::RemoveDups;
use RUM::TestUtils;

my $in = "$INPUT_DIR/RUM_NU_temp3.1";

for my $limit ((0, 1, 2, 4, 16, 64)) {
    my $out = temp_filename(TEMPLATE => "limit-$limit.XXXXXX");
    system "perl $Bin/../bin/limit_NU.pl $in $limit > $out";
    no_diffs($out, "$EXPECTED_DIR/RUM_NU-$limit.1");    
}

