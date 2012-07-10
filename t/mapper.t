#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 20;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::Alignment;
use RUM::Mapper;

my $single_forward = RUM::Mapper->new(
    alignments => [
        RUM::Alignment->new(
            readid => "seq.123a",
            chr => "chr1",
            seq => "ACGT",
            strand => '+',
            loc => 1)
    ]
);

ok   $single_forward->single;
ok    $single_forward->single_forward;
ok !  $single_forward->single_reverse;
ok ! $single_forward->joined;
ok ! $single_forward->unjoined;
ok ! $single_forward->is_empty;

my $joined = RUM::Mapper->new(
    alignments => [
        RUM::Alignment->new(
            readid => "seq.123",
            chr => "chr1",
            seq => "ACGT",
            strand => '+',
            loc => 1)
    ]
);

ok ! $joined->single;
ok ! $joined->single_forward;
ok ! $joined->single_reverse;
ok   $joined->joined;
ok ! $joined->unjoined;
ok ! $joined->is_empty;

my $unjoined = RUM::Mapper->new(
    alignments => [
        RUM::Alignment->new(
            readid => "seq.123a",
            chr => "chr1",
            seq => "ACGT",
            strand => '+',
            loc => 1),
        RUM::Alignment->new(
            readid => "seq.123b",
            chr => "chr1",
            seq => "ACGT",
            strand => '+',
            loc => 1)
    ]
);

ok ! $unjoined->single;
ok ! $unjoined->joined;
ok   $unjoined->unjoined;
ok ! $unjoined->is_empty;

my $empty = RUM::Mapper->new();

ok ! $empty->single;
ok ! $empty->joined;
ok ! $empty->unjoined;
ok   $empty->is_empty;
