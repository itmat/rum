#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 12;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::Alignment;

my $fwd = RUM::Alignment->new(readid => "seq.123a",
                              chr => "chr1",
                              seq => "ACGT",
                              strand => '+',
                              loc => 1);

ok   $fwd->is_forward,        "is forward";
ok ! $fwd->is_reverse,       "is not reverse";
ok   $fwd->contains_forward, "contains forward";
ok ! $fwd->contains_reverse, "does not contain reverse";

my $rev = $fwd->copy(readid => "seq.123b");

ok ! $rev->is_forward,       "is not forward";
ok   $rev->is_reverse,        "is reverse";
ok ! $rev->contains_forward, "does not contain forward";
ok   $rev->contains_reverse, "contains reverse";

my $both = $fwd->copy(readid => "seq.123");

ok ! $both->is_forward,       "is not forward";
ok ! $both->is_reverse,       "is not reverse";
ok   $both->contains_forward, "contains forward";
ok   $both->contains_reverse, "contains reverse";
