#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use FindBin qw($Bin);
use lib ("$Bin/../lib", "$Bin/../../lib");
use Data::Dumper;
use RUM::TestUtils;


my $unique_in     = "$SHARED_INPUT_DIR/RUM_Unique.sorted.1";
my $non_unique_in = "$SHARED_INPUT_DIR/RUM_NU.sorted.1";

my @files = ($unique_in, $non_unique_in);

my @tests = (
    {
        file => $unique_in,
        name => "test Unique Mappers",
        expected_cov => "RUM_Unique.cov",
        expected_footprint => qr/74381/
    },
    {
        file => $non_unique_in,
        name => "test Non-Unique Mappers",
        expected_cov => "RUM_NU.cov",
        expected_footprint => qr/67399/
    }
);

plan tests => 8 + 2 * scalar(@tests);

use_ok("RUM::Script::RumToCov");

{
    my @result;
    my $accumulator = sub {
        my ($start, $end, $cov) = @_;
        push @result, [ $start, $end, $cov ];
    };

    my $rum2cov = RUM::Script::RumToCov->new();
    $rum2cov->add_spans([ [5, 10, 1], 
                         [12, 15, 3] ]);
    $rum2cov->purge_spans($accumulator);
    is_deeply(\@result,
              [ [ 5, 10, 1],
                [ 12, 15, 3] ],
              'non-overlapping');

    $rum2cov = RUM::Script::RumToCov->new();
    $rum2cov->add_spans([ [5, 10, 1], 
                         [8, 15, 2] ]);
    undef @result;
    $rum2cov->purge_spans($accumulator);
    is_deeply(\@result,
              [[ 5, 8, 1 ],
               [ 8, 10, 3 ],
               [ 10, 15, 2 ]],
              'overlapping');

    $rum2cov = RUM::Script::RumToCov->new();
    $rum2cov->add_spans([[5, 10, 1]]);
    $rum2cov->add_spans([[8, 15, 2], [14, 19, 7]]);
    undef @result;
    $rum2cov->purge_spans($accumulator);
    is_deeply(\@result,
              [[5, 8, 1],
               [8, 10, 3],
               [10, 14, 2],
               [14, 15, 9],
               [15, 19, 7]]);

    $rum2cov = RUM::Script::RumToCov->new();
    $rum2cov->add_spans([[5, 10, 1]]);
    $rum2cov->add_spans([[8, 15, 2], [14, 19, 7]]);
    undef @result;

    $rum2cov->purge_spans($accumulator, 7);

    is_deeply(\@result, []);
    $rum2cov->purge_spans($accumulator, 9);
    is_deeply(\@result, [[5, 8, 1]]);
    undef @result;

    $rum2cov->purge_spans($accumulator, 15);
    is_deeply(\@result, [[8, 10, 3],
                         [10, 14, 2]]);
    $rum2cov->purge_spans($accumulator, 9);
    $rum2cov = RUM::Script::RumToCov->new();
    # 5 1
    # 10 -1
    # 10 1
    # 15 -1
    $rum2cov->add_spans([[5, 10, 1], [10, 15, 1]]);
    undef @result;
    $rum2cov->purge_spans($accumulator);
    is_deeply(\@result, [[5, 15, 1]]);

}


for my $test (@tests) {
    my $name = $test->{name};
    my $file = $test->{file};
    my $expected_cov = "$EXPECTED_DIR/$test->{expected_cov}";
    my $expected_footprint = $test->{expected_footprint};
    my $cov_out = temp_filename(TEMPLATE => "coverage.XXXXXX", UNLINK => 0);
    my $stats_out = temp_filename(TEMPLATE => "footprint.XXXXXX", UNLINK => 0);
    #$cov_out = "$name.cov";
    @ARGV = ($file, "-o", $cov_out, "--name", $name, "--stats", $stats_out, "-q");
    RUM::Script::RumToCov->main();
    no_diffs($cov_out, $expected_cov, "Coverage diffs: $expected_cov");
    open my $in, "<", $stats_out;
    my $footprint = <$in>;    
    like $footprint, qr/$expected_footprint/, "Footprint";
}

