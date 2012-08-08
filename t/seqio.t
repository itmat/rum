#!/usr/bin/env perl

use strict;
use warnings;
use autodie;

use Test::More tests => 2;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::SeqIO;

my $data = <<EOF;
>seq.123a
AC
G
T
>seq.123b
ACGT
EOF

open my $fh, "<", \$data;

my $io = RUM::SeqIO->new(-fh => $fh);

my $first = $io->next_seq;
is $first->readid, "seq.123a";
my $second = $io->next_seq;
is $second->readid, 'seq.123b';
