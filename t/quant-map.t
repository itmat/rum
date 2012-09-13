#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Data::Dumper;
use RUM::QuantMap;

my @tests;

{
    my $quant = RUM::SingleChromosomeQuantMap->new;
    
    $quant->add_feature(start => 5,  end => 15, data => 'a');
    $quant->add_feature(start => 10, end => 20, data => 'b');
    $quant->add_feature(start => 17, end => 20, data => 'c');
    $quant->add_feature(start => 30, end => 40, data => 'd');
    $quant->add_feature(start => 30, end => 33, data => 'e');
    $quant->add_feature(start => 37, end => 40, data => 'f');
    
    $quant->make_index;
    print Dumper($quant);

    push @tests, (
        [ $quant, undef, [[0, 50]],    [qw(a b c d e f)]],
        [ $quant, undef, [[0,  3]],    [qw()]],
        [ $quant, undef, [[8,  9]],    [qw(a)]],
        [ $quant, undef, [[8, 10]],    [qw(a b)]],
        [ $quant, undef, [[8, 11]],    [qw(a b)]],
        [ $quant, undef, [[100, 110]], [qw()]],        
    );

}

{
    my $quant = RUM::SingleChromosomeQuantMap->new;

    $quant->make_index;

    push @tests, (
        [ $quant, undef, [[0, 50]],   [qw()]],
    );

}
{
    my $quant = RUM::SingleChromosomeQuantMap->new;
    $quant->add_feature(start => 5, end => 15, data => 'a');
    $quant->make_index;

    push @tests, (
        [ $quant, undef, [[0, 50]],   [qw(a)]],
    );

}

{
    my $quant = RUM::QuantMap->new;
    $quant->add_feature(chromosome => 'chr1', start => 5,  end => 15, data => 'a');
    $quant->add_feature(chromosome => 'chr1', start => 10, end => 20, data => 'b');
    $quant->add_feature(chromosome => 'chr1', start => 17, end => 20, data => 'c');
    $quant->add_feature(chromosome => 'chr1', start => 30, end => 40, data => 'd');
    $quant->add_feature(chromosome => 'chr1', start => 30, end => 33, data => 'e');
    $quant->add_feature(chromosome => 'chr1', start => 37, end => 40, data => 'f');
    $quant->add_feature(chromosome => 'chr2', start => 5,  end => 15, data => 'g');
    $quant->add_feature(chromosome => 'chr2', start => 10, end => 20, data => 'h');
    $quant->add_feature(chromosome => 'chr2', start => 17, end => 20, data => 'i');
    $quant->add_feature(chromosome => 'chr2', start => 30, end => 40, data => 'j');
    $quant->add_feature(chromosome => 'chr2', start => 30, end => 33, data => 'k');
    $quant->add_feature(chromosome => 'chr2', start => 37, end => 40, data => 'l');
    $quant->make_index;
    push @tests, (
        [ $quant, 'chr1', [[0, 50]],    [qw(a b c d e f)]],
        [ $quant, 'chr1', [[0,  3]],    [qw()]],
        [ $quant, 'chr1', [[8,  9]],    [qw(a)]],
        [ $quant, 'chr1', [[8, 10]],    [qw(a b)]],
        [ $quant, 'chr1', [[8, 11]],    [qw(a b)]],
        [ $quant, 'chr1', [[100, 110]], [qw()]],
    );    
}

{
    my $quant = RUM::QuantMap->new;
    $quant->add_feature(
        chromosome => 2, 
        start => 3619936, 
        end => 3620384, 
        data => {});
    $quant->add_feature(
        chromosome => 2, 
        start => 3619936, 
        end => 3620090, 
        data => {});
    $quant->make_index;
    push @tests, (
        [ $quant, 2, [[3618155, 3618162],
                      [3618697, 3618722],
                      [3618901, 3618941], 
                      [3619861, 3619935]], []],
    );
}

plan tests => scalar @tests;

for my $test (@tests) {
    my ($quant, $chr, $spans, $covered) = @{ $test };

    my @covered;

    my $handler = sub {
        push @covered, shift->{data};
    };

    my $features = $quant->cover_features(spans => $spans, 
                                          chromosome => $chr,
                                          callback => $handler);

    @covered = sort @covered;

    is_deeply \@covered, $covered;
}

