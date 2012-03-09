#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 4;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::Script::MakeGuAndGnu;
use RUM::TestUtils;

sub all_ok {
    my ($type) = @_;
    my $u  = temp_filename(TEMPLATE => "$type-unique.XXXXXX");
    my $nu = temp_filename(TEMPLATE => "$type-non-unique.XXXXXX");
    @ARGV = ("$INPUT_DIR/X.1",
             "--unique", $u,
             "--non-unique", $nu,
             "--$type");
    RUM::Script::MakeGuAndGnu->main();
    no_diffs($u,  "$EXPECTED_DIR/$type-unique", "$type unique");
    no_diffs($nu, "$EXPECTED_DIR/$type-non-unique", "$type non-unique");
}

all_ok("paired");
all_ok("single");
