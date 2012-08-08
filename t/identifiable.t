#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 24;
use Test::Exception;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::Alignment;

my @tests = (
    {
        params => { readid => 'seq.123a' }, 
        name => 'forward read id',
        direction => 'a',
        order => 123,
    },
    {
        params => { readid => 'seq.123b' }, 
        name => 'reverse read id',
        direction => 'b',
        order => 123,
    },
    {
        params => { readid => 'seq.123' }, 
        name => 'joined read id',
        direction => '',
        order => 123,
    },
    {
        params => { readid => 'seq.456b' , order => 123, direction => 'a'}, 
        name => 'override',
        direction => 'a',
        order => 123,
    },
    {
        params => { readid => 'seq.456a', order => 123, direction => 'b' }, 
        name => 'reverse read id',
        direction => 'b',
        order => 123,
    },    
    {
        params => { readid => 'foobar|seq.123a' },
        name => 'enhanced read id',
        direction => 'a',
        order => 123,
        readid => 'foobar|seq.123a',
    },
    {
        params => { readid => 'foobar|seq.456b',
                    order => 123,
                    direction => 'a'},
        name => 'enhanced read id with override',
        direction => 'a',
        order => 123,
        readid => 'foobar|seq.123a',
    },
    {
        params => { readid => 'foobar',
                    order => 123,
                    direction => 'a'},
        name => 'raw read id with override',
        direction => 'a',
        order => 123,
        readid => 'foobar|seq.123a',
    },
);

for my $test (@tests) {
    my $name      = $test->{name};
    my $order     = $test->{order};
    my $direction = $test->{direction};

    my $readid = $test->{readid} || "seq.${order}${direction}";
    my $seq = RUM::Identifiable->new(%{ $test->{params} });

    is $seq->order,      $order,     "order from $name";
    is $seq->_direction, $direction, "direction from $name";
    is $seq->readid,     $readid,    "readid from $name";
}

