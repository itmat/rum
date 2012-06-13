#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 1;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::Script::MergeGnuAndTnuAndCnu;
use RUM::TestUtils;
use File::Temp;
use Data::Dumper;

my $gnu = "$INPUT_DIR/GNU.1";
my $tnu = "$INPUT_DIR/TNU.1";
my $cnu = "$INPUT_DIR/CNU.1";

my $bowtie_nu  = temp_filename(TEMPLATE => "bowtie-nu.XXXXXX");
@ARGV = ("--gnu", $gnu, "--tnu", $tnu, "--cnu", $cnu, "--out", $bowtie_nu);
RUM::Script::MergeGnuAndTnuAndCnu->main();

my $same_read_id = sub { $_[0]->readid_directionless eq
                         $_[1]->readid_directionless };
use vars qw($a $b);
sub import_and_sort {
    my $file = shift;

    my $groups = RUM::RUMIO->new(-file => $file)->group_by($same_read_id);
    my @groups;
    while (my $group = $groups->next_val) {
        my @pairs;
        my $pairs = $group->group_by(\&RUM::Identifiable::is_mate);
        while (my $pair = $pairs->next_val) {
            push @pairs, $pair->ireduce(sub { $a . $b->raw . "\n" }, "");
        }
        @pairs = sort @pairs;
        push @groups, \@pairs;
    }
    return \@groups;
}

my $got = import_and_sort($bowtie_nu);
my $expected = import_and_sort("$EXPECTED_DIR/BowtieNU.1");
is_deeply($got, $expected,
          "Output is sorted by read id, pairs are together");

