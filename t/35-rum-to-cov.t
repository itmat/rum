#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../lib";

use RUM::TestUtils;

my $unique_in = "$SHARED_INPUT_DIR/RUM_Unique.sorted.1";
my $non_unique_in = "$SHARED_INPUT_DIR/RUM_NU.sorted.1";

my @files = ($unique_in, $non_unique_in);

my @tests = (
    {
        file => $unique_in,
        name => "test Unique Mappers",
        expected_cov => "RUM_Unique.cov",
        expected_footprint => qr/73771/
    },
    {
        file => $non_unique_in,
        name => "test Non-Unique Mappers",
        expected_cov => "RUM_NU.cov",
        expected_footprint => qr/66922/
    }
);

plan tests => 1 + 2 * scalar(@tests);

use_ok("RUM::Script::RumToCov");

for my $test (@tests) {
    my $name = $test->{name};
    my $file = $test->{file};
    my $expected_cov = "$EXPECTED_DIR/$test->{expected_cov}";
    my $expected_footprint = $test->{expected_footprint};
    my $cov_out = temp_filename(TEMPLATE => "coverage.XXXXXX", UNLINK => 0);
    my $stats_out = temp_filename(TEMPLATE => "footprint.XXXXXX", UNLINK => 0);

    @ARGV = ($file, "-o", $cov_out, "--name", $name, "--stats", $stats_out);
    RUM::Script::RumToCov->main();
    no_diffs($cov_out, $expected_cov, "Coverage diffs: $expected_cov");
    open my $in, "<", $stats_out;
    $_ = <$in>;    
    ok(/$expected_footprint/, "Footprint");
}
