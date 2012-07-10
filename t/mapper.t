#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 16;
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

ok   $single_forward->is_single;
ok ! $single_forward->is_joined;
ok ! $single_forward->is_unjoined;
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

ok ! $joined->is_single;
ok   $joined->is_joined;
ok ! $joined->is_unjoined;
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

ok ! $unjoined->is_single;
ok ! $unjoined->is_joined;
ok   $unjoined->is_unjoined;
ok ! $unjoined->is_empty;

my $empty = RUM::Mapper->new();

ok ! $empty->is_single;
ok ! $empty->is_joined;
ok ! $empty->is_unjoined;
ok   $empty->is_empty;
