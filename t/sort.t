#!perl
# -*- cperl -*-

use Test::More tests => 24;
use lib "lib";

use strict;
use warnings;

BEGIN { 
  use_ok('RUM::Sort', qw(by_location cmpChrs));
}


my @less_than = (
    [{chr => "chr1"}, {chr => "chr2"}, "chromosome"],
    [{chr => "chr1", start => 0},
     {chr => "chr2", start => 1}, "start"],
    [{chr => "chr1", start => 1, end => 3},
     {chr => "chr2", start => 1, end => 4}, "end"],
    [{chr => "chr1", start => 1, end => 3, seqnum => 1},
     {chr => "chr2", start => 1, end => 3, seqnum => 2}, "seqnum"],
    [{chr => "chr1", start => 1, end => 3, seqnum => 1, seq => "a"},
     {chr => "chr2", start => 1, end => 3, seqnum => 1, seq => "c"}, "seqnum"],

    [{}, {chr => "chr2"}, "chromosome"],
    [{},
     {chr => "chr2", start => 1}, "start"],
    [{},
     {chr => "chr2", start => 1, end => 4}, "end"],
    [{},
     {chr => "chr2", start => 1, end => 3, seqnum => 2}, "seqnum"],
    [{},
     {chr => "chr2", start => 1, end => 3, seqnum => 1, seq => "c"}, "seqnum"],

);


for my $comparison (@less_than) {
    my ($aye, $bee, $msg) = @$comparison;
    ok(by_location($aye, $bee) < 0, $msg);
    ok(by_location($bee, $aye) > 0, "$msg (reversed)");

}

ok(cmpChrs('chrV', 'chrX') < 0);
ok(cmpChrs('chrX', 'chrM') < 0);
ok(cmpChrs('chrM', 'chrV') > 0);
