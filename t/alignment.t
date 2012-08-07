#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 21;
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
is $fwd->as_forward->readid, "seq.123a";
is $fwd->as_reverse->readid, "seq.123b";
is $fwd->as_unified->readid, "seq.123";


my $rev = $fwd->copy(direction => 'b');

ok ! $rev->is_forward,       "is not forward";
ok   $rev->is_reverse,        "is reverse";
ok ! $rev->contains_forward, "does not contain forward";
ok   $rev->contains_reverse, "contains reverse";
is $rev->as_forward->readid, "seq.123a";
is $rev->as_reverse->readid, "seq.123b";
is $rev->as_unified->readid, "seq.123";


my $both = $fwd->copy(direction => '');

ok ! $both->is_forward,       "is not forward";
ok ! $both->is_reverse,       "is not reverse";
ok   $both->contains_forward, "contains forward";
ok   $both->contains_reverse, "contains reverse";


is $both->as_forward->readid, "seq.123a";
is $both->as_reverse->readid, "seq.123b";
is $both->as_unified->readid, "seq.123";
