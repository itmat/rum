#!perl
# -*- cperl -*-

use Test::More tests => 22;
use FindBin qw($Bin);
use lib "lib";

use strict;
use warnings;
use autodie;

use RUM::BlatIO;

my $blatio = RUM::BlatIO->new(-file => "$Bin/data/parse-blat-out/R.1.blat");

is_deeply(
    $blatio->fields,
    ['match',
     'mismatch',
     'rep. match',
     "N's",
     'Q gap count',
     'Q gap bases',
     'T gap count',
     'T gap bases',
     'strand',
     'Q name',
     'Q size',
     'Q start',
     'Q end',
     'T name',
     'T size',
     'T start',
     'T end',
     'block count',
     'blockSizes',
     'qStarts',
     'tStarts']);
