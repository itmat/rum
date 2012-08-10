#!/usr/bin/env perl

use strict;
use warnings;
use autodie;

use Test::More tests => 10;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::SeqIO;

my $fasta = <<EOF;
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
    open my $fh, "<", \$fasta;
    
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
    my $first = $io->next_seq;
    is $first->readid, 'SRX030478.31 C3PO_0001:7:1:26:1142 length=75';
    is $first->seq,    'GAGAAACTCCAAATGTGATCTTGCGTTGNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN';
    is $first->qual,   'ABBCBBBBCCB@BBB?BBBB%%%%%%%%!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!';

    my $second = $io->next_seq;
    is $second->readid, 'SRX030478.32 C3PO_0001:7:1:26:196 length=75';
    is $second->seq,    'CCTAATTTCTTCCCTCCAAATTTATAATNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN';
    is $second->qual,   'BBBB@A?@BBA@@@?@A@@=%%%%%%%%!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!';

    open my $reads_fh, '>', \(my $reads_str);
    open my $quals_fh, '>', \(my $quals_str);
    my $reads_out = RUM::SeqIO->new(-fh => $reads_fh);
    my $quals_out = RUM::SeqIO->new(-fh => $quals_fh);

    $reads_out->write_seq($first);
    $quals_out->write_qual_as_seq($first);
    $reads_out->write_seq($second);
    $quals_out->write_qual_as_seq($second);

    is($reads_str, <<'EOF'
>SRX030478.31 C3PO_0001:7:1:26:1142 length=75
GAGAAACTCCAAATGTGATCTTGCGTTGNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN
>SRX030478.32 C3PO_0001:7:1:26:196 length=75
CCTAATTTCTTCCCTCCAAATTTATAATNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN
EOF
);

    is($quals_str, <<'EOF'
>SRX030478.31 C3PO_0001:7:1:26:1142 length=75
ABBCBBBBCCB@BBB?BBBB%%%%%%%%!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
>SRX030478.32 C3PO_0001:7:1:26:196 length=75
BBBB@A?@BBA@@@?@A@@=%%%%%%%%!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
EOF
);
       
}
