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

@ARGV = ("$INPUT_DIR/junctions_all_temp.rum", "-o", $all_rum, "--location", 1, "--skip", 1);
RUM::Script::SortByLocation->main();
no_diffs($all_rum, "$EXPECTED_DIR/junctions_all.rum", 
         "RUM format, All junctions");

@ARGV = ("$INPUT_DIR/junctions_all_temp.bed", "-o", $all_bed,
         "--chr", 1, "--start", 2, "--end", 3, "-skip", 1);
RUM::Script::SortByLocation->main();
no_diffs($all_bed, "$EXPECTED_DIR/junctions_all.bed",
         "bed format, all junctions");

@ARGV = ("$INPUT_DIR/junctions_high-quality_temp.bed", "-o", $high_bed,
         "--chr", 1, "--start", 2, "--end", 3, "-skip", 1);
RUM::Script::SortByLocation->main();
no_diffs($high_bed, "$EXPECTED_DIR/junctions_high-quality.bed",
         "bed format, high-quality junctions");


