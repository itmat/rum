#!/usr/bin/env perl

use strict;
use warnings;

my $n = 75;

my $i = 1;

while (defined (local $_ = <ARGV>)) {

    next if /^>/;
    for my $i (0 .. 99) {

        my $off = int(rand(length() - $n));
        my $read = substr $_, $off, $n;
        printf ">read%d\n%s\n", $i++, $read;
    }
}
