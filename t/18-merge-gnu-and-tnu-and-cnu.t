#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 1;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::Script::MergeGnuAndTnuAndCnu;
use RUM::TestUtils qw(no_diffs);
use File::Temp;

my $tempdir = "$Bin/tmp";
my $expected_dir = "$Bin/expected/merge_gnu_and_tnu_and_cnu";
my $in_dir       = "$Bin/data/merge_gnu_and_tnu_and_cnu";

sub temp_filename {
    my ($template) = @_;
    File::Temp->new(
        DIR => "$Bin/tmp",
        UNLINK => 0,
        TEMPLATE => $template);
}

my $gnu = "$in_dir/GNU.1";
my $tnu = "$in_dir/TNU.1";
my $cnu = "$in_dir/CNU.1";

sub merge_ok {
    my $bowtie_nu  = temp_filename("bowtie-nu.XXXXXX");
    @ARGV = ($gnu, $tnu, $cnu, $bowtie_nu);
    
    RUM::Script::MergeGnuAndTnuAndCnu->main();
    no_diffs($bowtie_nu, "$expected_dir/BowtieNU.1");
}

merge_ok();

