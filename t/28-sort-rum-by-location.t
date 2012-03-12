#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 2;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::Script::SortRumByLocation;
use RUM::TestUtils;

our $SCRIPT = "$Bin/../bin/sort_RUM_by_location.pl";

my @types = qw(Unique NU);

for my $type (@types) {
    my $in       = "$INPUT_DIR/RUM_$type.1";
    my $out      = temp_filename(TEMPLATE => "$type.XXXXXX");
    @ARGV = ("-o", $out, $in);
    RUM::Script::SortRumByLocation->main();
    is_sorted_by_location($out);
}
