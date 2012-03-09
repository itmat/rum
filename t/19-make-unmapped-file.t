#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 1;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::Script::MakeUnmappedFile;
use RUM::TestUtils qw(no_diffs);
use File::Temp;

my $tempdir = "$Bin/tmp";
my $expected_dir = "$Bin/expected/make_unmapped_file";
my $in_dir       = "$Bin/data/make_unmapped_file";

sub temp_filename {
    my ($template) = @_;
    File::Temp->new(
        DIR => "$Bin/tmp",
        UNLINK => 0,
        TEMPLATE => $template);
}

my $reads      = "$in_dir/reads.fa.1";
my $unique     = "$in_dir/BowtieUnique.1";
my $non_unique = "$in_dir/BowtieNU.1";

sub merge_ok {
    my $unmapped  = temp_filename("unmapped.XXXXXX");
    @ARGV = (
        "--reads-in", $reads, 
        "--unique-in", $unique, 
        "--non-unique-in", $non_unique, 
        "--output", $unmapped,
        "--paired",
        "-q");
    
    my $status = RUM::Script::MakeUnmappedFile->main();
    print "Status is $status\n";
    no_diffs($unmapped, "$expected_dir/R.1");
}

merge_ok();

