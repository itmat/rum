#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 4;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::Script::MakeGuAndGnu;
use RUM::TestUtils;
use Data::Dumper;

my %inputs = (
    single => "$INPUT_DIR/single_X.1",
    paired => "$INPUT_DIR/X.1",
);

for my $type (qw(paired single)) {
    my $u  = temp_filename(TEMPLATE => "$type-unique.XXXXXX", UNLINK => 0);
    my $nu = temp_filename(TEMPLATE => "$type-non-unique.XXXXXX", UNLINK => 0);

    my $script = RUM::Script::MakeGuAndGnu->new;
    open my $in, '<', $inputs{$type};
    $script->{paired} = 1 if $type eq 'paired';
    $script->{max_distance_between_paired_reads} = 500000 if $type eq 'paired';
    $script->parse_output($in, $u, $nu);
    close $u;
    close $nu;
    same_contents_sorted($u,  "$EXPECTED_DIR/$type-unique", "$type unique");
    same_contents_sorted($nu, "$EXPECTED_DIR/$type-non-unique", "$type non-unique");
}

my $class = "RUM::Script::MakeGuAndGnu";

if (0) { 

    my $all_ns = RUM::Alignment->new(
        readid => "seq.1a",
        strand => "+",
        chr => "chr1",
        loc => 1,
        seq => "NNNNNNNN");

    my $no_ns = RUM::Alignment->new(
        readid => "seq.1a",
        strand => "+",
        chr => "chr1",
        loc => 1,
        seq => "ACTACT");

    my $no_ns_cleaned = RUM::Alignment->new(
        readid => "seq.1a",
        strand => "+",
        chr => "chr1",
        locs => [[2, 7]],
        seq => "ACTACT");

    my $some_ns = RUM::Alignment->new(
        readid => "seq.1a",
        strand => "+",
        chr => "chr1",
        loc => 1,
        seq => "NNACTACTN");

    my $some_ns_cleaned = RUM::Alignment->new(
        readid => "seq.1a",
        strand => "+",
        chr => "chr1",
        locs => [[4, 9]],
        seq => "ACTACT");

    is($class->clean_alignment($all_ns), undef, "All Ns is undef");

    is_deeply($class->clean_alignment($no_ns), 
              $no_ns_cleaned,
               "No Ns");
    is_deeply($class->clean_alignment($some_ns), 
              $some_ns_cleaned,
               "Some Ns");
}

sub by_start_loc {
     { $a->[0][0] <=> $b->[0][0] };
}

if (0) {
    diag "Testing split forward and reverse";
    my $table = [
        ["seq.1a", "+", "chr1", "1", "AAAAAAAAAA"],
        ["seq.1b", "-", "chr1", "2", "AAAAAAAAAA"],
        ["seq.1a", "+", "chr1", "3", "AAAAAAAAAA"],
        ["seq.1b", "-", "chr1", "4", "AAAAAAAAAA"]
    ];

    my $iter = RUM::BowtieIO->new(-table => $table)->aln_iterator;

    my ($fwd, $rev) = $class->split_forward_and_reverse($iter->to_array);
    my @fwd_locs = map $_->locs, @$fwd;
    my @rev_locs = map $_->locs, @$rev;

    @fwd_locs = sort by_start_loc @fwd_locs;
    @rev_locs = sort by_start_loc @rev_locs;

    is_deeply(\@fwd_locs, [[[2,11]],[[4,13]]], "Forward locations");
    is_deeply(\@rev_locs, [[[3,12]],[[5,14]]], "Reverse locations");
}

