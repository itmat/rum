#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 4;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::Script::MergeGuAndTu;
use RUM::TestUtils qw(no_diffs);
use File::Temp;

my $tempdir = "$Bin/tmp";
my $expected_dir = "$Bin/expected/merge_gu_and_tu";

sub temp_filename {
    my ($template) = @_;
    File::Temp->new(
        DIR => "$Bin/tmp",
        UNLINK => 0,
        TEMPLATE => $template);
}



my $gu  = "$Bin/data/GU.1";
my $tu  = "$Bin/data/TU.1";
my $gnu = "$Bin/data/GNU.1";
my $tnu = "$Bin/data/TNU.1";

sub paired_ok {
    my $bowtie_unique  = temp_filename("paired-bowtie-unique.XXXXXX");
    my $cnu = temp_filename("paired-cnu.XXXXXX");
    @ARGV = ("--gu", $gu, 
             "--tu", $tu, 
             "--gnu", $gnu, 
             "--tnu", $tnu,
             "--bowtie-unique", $bowtie_unique, 
             "--cnu", $cnu, 
             "--paired", 
             "--read-length", 75);
    
    RUM::Script::MergeGuAndTu->main();
    no_diffs($bowtie_unique, "$expected_dir/paired-bowtie-unique");
    no_diffs($cnu, "$expected_dir/paired-cnu");
}

sub single_ok {
    my $bowtie_unique  = temp_filename("single-bowtie-unique.XXXXXX");
    my $cnu = temp_filename("single-cnu.XXXXXX");
    @ARGV = ("--gu", $gu, 
             "--tu", $tu, 
             "--gnu", $gnu, 
             "--tnu", $tnu,
             "--bowtie-unique", $bowtie_unique, 
             "--cnu", $cnu, 
             "--single", 
             "--read-length", 75);
    
    RUM::Script::MergeGuAndTu->main();
    no_diffs($bowtie_unique, "$expected_dir/single-bowtie-unique");
    no_diffs($cnu, "$expected_dir/single-cnu");
}


paired_ok();
single_ok();
