#!/usr/bin/env perl

use strict;
use warnings;

use List::Util qw(shuffle);

my @lines = (<>);

my @header = @lines[ 0 .. 4 ];
my @data = shuffle @lines [ 5 .. $#lines ];

for my $line (@header, @data) {
    print $line;
}
