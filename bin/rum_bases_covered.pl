#!/usr/bin/env perl

use strict;
use warnings;

if (@ARGV != 1) {
    die "Usage: $0 COV_FILE\nWhere COV_FILE is a RUM_Unique.cov or RUM_NU.cov file\n\n";
}

open my $in, '<', $ARGV[0];

my $bases = 0;

# Skip the header
<$in>;

while (defined(my $line = <$in>)) {
    my ($chr, $start, $end) = split /\t/, $line;
    $bases += $end - $start;
}

print "Bases covered: $bases\n";
