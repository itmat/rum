#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 2;
use FindBin qw($Bin);
use File::Copy;
use lib "$Bin/../lib";
#use RUM::Script::SortRumById;
use RUM::TestUtils;

my $in = "$INPUT_DIR/RUM_NU_idsorted.1";
my $out_unique = temp_filename(TEMPLATE => "unique.XXXXXX");
my $out_non_unique = temp_filename(TEMPLATE => "non-unique.XXXXXX");

@ARGV = ($in, $out_non_unique, $out_unique);
#RUM::Script::SortRumById->main();
system("perl $Bin/../bin/removedups.pl @ARGV") == 0 or die "Bad exit status";
no_diffs($out_non_unique, "$EXPECTED_DIR/RUM_NU_temp3.1");
no_diffs($out_unique, "$EXPECTED_DIR/RUM_Unique_temp2.1");
