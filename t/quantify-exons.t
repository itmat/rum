#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../lib";

use RUM::TestUtils;

my $exons = "$INPUT_DIR/inferred_internal_exons.txt";
my $sam   = "$INPUT_DIR/rum.sam";

plan tests => 1;

my $out = temp_filename(TEMPLATE => "quantify_exons.XXXXXX");
@ARGV = ($exons, $sam, $out);

system "perl", "bin/quantify_exons.pl", @ARGV;

same_contents_sorted($out,  "$EXPECTED_DIR/quantified_exons");

