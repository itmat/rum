#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 2;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::Script::MakeGuAndGnu;
use File::Temp;
my $in = "$Bin/data/X.1";
my $tempdir = "$Bin/tmp";

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
    @ARGV = ($in, $u, $nu, "paired");
    RUM::Script::MakeGuAndGnu->main();
    pass("hi");
}

sub single_ok {
    my $u  = temp_filename("single-unique.XXXXXX");
    my $nu = temp_filename("single-non-unique.XXXXXX");
    @ARGV = ($in, $u, $nu, "single");
    RUM::Script::MakeGuAndGnu->main();
    pass("hi");
}

paired_ok();
single_ok();
