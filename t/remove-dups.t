#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 5;
use Test::Exception;
use FindBin qw($Bin);
use File::Copy;
use lib "$Bin/../lib";
use RUM::Script::RemoveDups;
use RUM::TestUtils;

my $in = "$INPUT_DIR/RUM_NU_idsorted.1";
my $out_unique = temp_filename(TEMPLATE => "unique.XXXXXX");
my $out_non_unique = temp_filename(TEMPLATE => "non-unique.XXXXXX");

sub remove_dups {
    @ARGV = @_;
    RUM::Script::RemoveDups->main();
}

remove_dups($in, "--non-unique", $out_non_unique, "--unique", $out_unique, "-q");
same_contents_sorted($out_non_unique, "$EXPECTED_DIR/RUM_NU_temp3.1");
no_diffs($out_unique, "$EXPECTED_DIR/RUM_Unique_temp2.1");

throws_ok {
    remove_dups("--unique-out", "foo", "--non-unique-out", "bar")
} qr/input file/, "need input file";

throws_ok {
    remove_dups("--non-unique-out", "bar", "in")
} qr/--unique-out/, "need unique out";

throws_ok {
    remove_dups("--unique-out", "foo", "bar", "in")
} qr/--non-unique-out/, "need non-unique out";
