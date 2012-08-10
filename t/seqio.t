#!/usr/bin/env perl

use strict;
use warnings;
use autodie;

use Test::More tests => 8;
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

my $fastq = <<'EOF';
@SRX030478.31 C3PO_0001:7:1:26:1142 length=75
GAGAAACTCCAAATGTGATCTTGCGTTGNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN
+SRX030478.31 C3PO_0001:7:1:26:1142 length=75
ABBCBBBBCCB@BBB?BBBB%%%%%%%%!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
@SRX030478.32 C3PO_0001:7:1:26:196 length=75
CCTAATTTCTTCCCTCCAAATTTATAATNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN
+SRX030478.32 C3PO_0001:7:1:26:196 length=75
BBBB@A?@BBA@@@?@A@@=%%%%%%%%!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
EOF

{
    open my $fh, "<", \$data;
    
    my $io = RUM::SeqIO->new(-fh => $fh);
    
    my $first = $io->next_seq;
    is $first->readid, "seq.123a";
    my $second = $io->next_seq;
    is $second->readid, 'seq.123b';
}

{
    open my $fh, '<', \$fastq;
    my $io = RUM::SeqIO->new(-fh => $fh,
                             fmt => 'fastq');
    my $rec = $io->next_seq;
    is $rec->readid, 'SRX030478.31 C3PO_0001:7:1:26:1142 length=75';
    is $rec->seq,    'GAGAAACTCCAAATGTGATCTTGCGTTGNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN';
    is $rec->qual,   'ABBCBBBBCCB@BBB?BBBB%%%%%%%%!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!';

    $rec = $io->next_seq;
    is $rec->readid, 'SRX030478.32 C3PO_0001:7:1:26:196 length=75';
    is $rec->seq,    'CCTAATTTCTTCCCTCCAAATTTATAATNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN';
    is $rec->qual,   'BBBB@A?@BBA@@@?@A@@=%%%%%%%%!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!';
}
