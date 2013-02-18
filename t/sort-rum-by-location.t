#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 8;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::Script::SortRumByLocation;
use RUM::TestUtils;

my @types = qw(Unique NU);

for my $type (@types) {
    my $in         = "$INPUT_DIR/RUM_$type.1";
    my $out        = temp_filename(TEMPLATE => "$type.XXXXXX");
    my $chr_counts = temp_filename(TEMPLATE => "$type.chrcounts.XXXXXX");
    @ARGV = ("--chr-counts-out", $chr_counts, "-o", $out, $in);
    RUM::Script::SortRumByLocation->main();
    is -s $in, -s $out, "Sorted file is same size";
    is_sorted_by_location($out);
}

for my $type (@types) {
    my $in       = "$INPUT_DIR/RUM_$type.1";
    my $out        = temp_filename(TEMPLATE => "$type.XXXXXX");
    my $chr_counts = temp_filename(TEMPLATE => "$type.chrcounts.XXXXXX");
    @ARGV = ("--chr-counts-out", $chr_counts, "-o", $out, $in, "--max-chunk", 8, "--allow-small-chunks");
    RUM::Script::SortRumByLocation->main();
    is -s $in, -s $out, "Sorted file is same size";
    is_sorted_by_location($out);
}
