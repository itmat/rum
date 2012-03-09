#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 1;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::Script::MergeGnuAndTnuAndCnu;
use RUM::TestUtils;
use File::Temp;

my $gnu = "$INPUT_DIR/GNU.1";
my $tnu = "$INPUT_DIR/TNU.1";
my $cnu = "$INPUT_DIR/CNU.1";

my $bowtie_nu  = temp_filename(TEMPLATE => "bowtie-nu.XXXXXX");
@ARGV = ("--gnu", $gnu, "--tnu", $tnu, "--cnu", $cnu, "--out", $bowtie_nu);
RUM::Script::MergeGnuAndTnuAndCnu->main();
no_diffs($bowtie_nu, "$EXPECTED_DIR/BowtieNU.1");

