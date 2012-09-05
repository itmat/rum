#!/usr/bin/env perl

use strict;
use warnings;

use Test::More qw(tests 1);
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Data::Dumper;
use RUM::QuantMap;



{
    my $quant = RUM::QuantMap->new;

    $quant->add_feature(start => 5,  end => 15, data => 'a');
    $quant->add_feature(start => 10, end => 20, data => 'b');
    $quant->add_feature(start => 17, end => 20, data => 'c');
    $quant->add_feature(start => 30, end => 40, data => 'd');
    $quant->add_feature(start => 30, end => 33, data => 'e');
    $quant->add_feature(start => 37, end => 40, data => 'f');
    
    $quant->partition;

    my @tests = (
        [ 0, 50, [qw(a b c d e f)]],
        [ 0, 3, [qw()]],
    );

    for my $test (@tests) {
        my ($start, $end, $covered) = @{ $test };
        my $features = $quant->covered_features(start => $start, end => $end);
        my @names = sort map { $_->{data} } @{ $features };
        print Dumper($quant);
        is_deeply \@names, $covered;
    }
    
}
