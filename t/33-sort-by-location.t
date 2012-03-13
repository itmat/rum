#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 4;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use_ok("RUM::Script::SortByLocation");
use RUM::TestUtils;

my $all_rum = temp_filename(TEMPLATE => "all-rum.XXXXXX");
my $all_bed = temp_filename(TEMPLATE => "all-rum.XXXXXX");
my $high_bed = temp_filename(TEMPLATE => "all-rum.XXXXXX");

@ARGV = ("$INPUT_DIR/junctions_all_temp.rum", $all_rum, "-location_column", 1, "-skip", 1);
RUM::Script::SortByLocation->main();
no_diffs($all_rum, "$EXPECTED_DIR/junctions_all.rum");

@ARGV = ("$INPUT_DIR/junctions_high-quality_temp.bed", $all_rum, "-location_columns", "1,2,3", "-skip", 1);
RUM::Script::SortByLocation->main();
no_diffs($all_rum, "$EXPECTED_DIR/junctions_high-quality.bed");

@ARGV = ("$INPUT_DIR/junctions_all_temp.bed", $all_rum, "-location_columns", "1,2,3", "-skip", 1);
RUM::Script::SortByLocation->main();
no_diffs($all_rum, "$EXPECTED_DIR/junctions_all.bed");


