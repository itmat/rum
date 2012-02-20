#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 8;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::Workflow qw(make_paths report);
use RUM::TestUtils qw(:all);

our $ROOT = "$Bin/../_testing";
our $TEST_DATA_TARBALL   = "$ROOT/rum-test-data.tar.gz";
our $OUT_DIR = "$ROOT/12-sort-rum-by-location";
our $IN_DIR = "$ROOT/rum-test-data/sort-rum-by-location/";
download_test_data($TEST_DATA_TARBALL);
make_paths($OUT_DIR);

our $SCRIPT = "$Bin/../orig/scripts/sort_RUM_by_location.pl";

my @types = qw(Unique NU);
my @chunks = (1, 2);

for my $type (@types) {
    for my $chunk (@chunks) {
        my $in       = "$IN_DIR/RUM_$type.$chunk";
        my $expected = "$IN_DIR/RUM_$type.sorted.$chunk";
        my $out      = "$OUT_DIR/RUM_$type.sorted.$chunk";
        my $output   = `perl $SCRIPT $in $out -maxchunksize 100 -allowsmallchunks`;
        no_diffs $out, $expected, "sort-rum-by-location-$type-$chunk";
    }
}

for my $type (@types) {
    for my $chunk (@chunks) {
        my $in       = "$IN_DIR/RUM_$type.$chunk";
        my $expected = "$IN_DIR/RUM_$type.sorted.$chunk";
        my $out      = "$OUT_DIR/RUM_$type.sorted.$chunk-nosplit";
        my $output   = `perl $SCRIPT $in $out`;
        no_diffs $out, $expected, "sort-rum-by-location-nosplit-$type-$chunk";
    }
}
