#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 2;
use FindBin qw($Bin);
use lib "$Bin/../../lib";
use RUM::Script::ParseBlatOut;
use RUM::TestUtils;

my $reads         = "$INPUT_DIR/R.1";
my $blat_results  = "$INPUT_DIR/R.1.blat";
my $mdust_results = "$INPUT_DIR/R.mdust.1";
my $unique = temp_filename(TEMPLATE => "unique.XXXXXX");
my $non_unique = temp_filename(TEMPLATE => "non-unique.XXXXXX");

$unique = 'u';
$non_unique = 'nu';

@ARGV = (
   "--reads-in", $reads,
   "--blat-in", $blat_results,
   "--mdust-in", $mdust_results,
   "--unique-out", $unique,
   "--non-unique-out", $non_unique,
   "-q");
RUM::Script::ParseBlatOut->main();
no_diffs($unique, "$EXPECTED_DIR/BlatUnique.1");
no_diffs($non_unique, "$EXPECTED_DIR/BlatNU.1");
