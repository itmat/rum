#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 4;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::Script::MakeGuAndGnu;
use RUM::TestUtils qw(no_diffs);
use File::Temp;

my $in = "$Bin/data/X.1";
my $tempdir = "$Bin/tmp";
my $expected_dir = "$Bin/expected/make_gu_and_gnu";

sub temp_filename {
    my ($template) = @_;
    File::Temp->new(
        DIR => "$Bin/tmp",
        UNLINK => 0,
        TEMPLATE => $template);
}

sub paired_ok {
    my $u  = temp_filename("paired-unique.XXXXXX");
    my $nu = temp_filename("paired-non-unique.XXXXXX");
    @ARGV = ($in, "--unique", $u, "--non-unique", $nu, "--paired");
    RUM::Script::MakeGuAndGnu->main();
    no_diffs($u,  "$expected_dir/paired-unique", "paired unique");
    no_diffs($nu, "$expected_dir/paired-non-unique", "paired non-unique");
}

sub single_ok {
    my $u  = temp_filename("single-unique.XXXXXX");
    my $nu = temp_filename("single-non-unique.XXXXXX");
    @ARGV = ($in, "--unique", $u, "--non-unique", $nu, "--single");

    RUM::Script::MakeGuAndGnu->main();
    no_diffs($u,  "$expected_dir/single-unique", "single unique");
    no_diffs($nu, "$expected_dir/single-non-unique", "single non-unique");
}

paired_ok();
single_ok();
