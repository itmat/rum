#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 1;
use FindBin qw($Bin);
use File::Copy;
use lib "$Bin/../lib";
use RUM::Script::LimitNU;
use RUM::TestUtils;

my $unique_in     = "$INPUT_DIR/RUM_Unique.1";
my $non_unique_in = "$INPUT_DIR/RUM_NU.1";
my $reads_in      = "$INPUT_DIR/reads.fa.1";
my $quals_in      = "$INPUT_DIR/quals.fa.1";

my $sam_out = temp_filename(TEMPLATE => "sam.XXXXXX");

@ARGV = ($unique_in, $non_unique_in, $reads_in, $quals_in, $sam_out);
#    RUM::Script::R->main();

system("$Bin/../bin/rum2sam.pl @ARGV");
no_diffs($sam_out, "$EXPECTED_DIR/RUM.sam.1");    


