#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 3;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::Script::FinalCleanup;
use RUM::TestUtils;

my $unique_in = "$INPUT_DIR/RUM_Unique_temp.1";
my $nu_in     = "$INPUT_DIR/RUM_NU_temp.1";

my $unique_out = temp_filename(TEMPLATE=>"unique.XXXXXX");
my $nu_out = temp_filename(TEMPLATE=>"nu.XXXXXX");
my $sam_header_out = temp_filename(TEMPLATE=>"sam_header.XXXXXX");

@ARGV = ("--unique-in", $unique_in, 
         "--non-unique-in", $nu_in, 
         "--genome", $RUM::TestUtils::GENOME_FA,
         "--unique-out", $unique_out, 
         "--non-unique-out", $nu_out,
         "--sam-header-out", $sam_header_out);

RUM::Script::FinalCleanup->main();
no_diffs($unique_out, 
         "$EXPECTED_DIR/unique-out", 
         "unique out");
no_diffs($nu_out, 
         "$EXPECTED_DIR/non-unique-out", 
         "non-unique out");
no_diffs($sam_header_out, 
         "$EXPECTED_DIR/sam-header-out", 
         "sam-header out");



