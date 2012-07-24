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

my $rec = $blatio->peekable->peek(25);

is $rec->readid, 'seq.17a', 'readid';
is $rec->chromosome, '5', 'chromosome';

#is $rec->match,    34, 'match';
#is $rec->mismatch,  0, 'mismatch';
#is $rec->rep_match, 0, 'rep_match';
#is $rec->ns,        2, 'ns';

#is $rec->q_gap_count, 1, 'q_gap_count';
#is $rec->q_gap_bases, 1, 'q_gap_bases';
#is $rec->q_gap_bases, 1, 't_gap_count';
#is $rec->q_gap_bases, 6, 't_gap_bases';

#is $rec->strand, '-', 'strand';

#is $rec->q_name, 'seq.17a', 'q_name';
#is $rec->q_size,  75,       'q_size';
#is $rec->q_start,  0,       'q_start';
#is $rec->q_end,   37,       'q_end';

#is $rec->t_name,         5, 't_name';
#is $rec->t_size,  26975502, 't_size';
#is $rec->t_start, 12852469, 't_start';
#is $rec->t_end,   12852511, 't_end';
