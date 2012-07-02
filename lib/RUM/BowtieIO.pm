package RUM::BowtieIO;

use strict;
use warnings;

use base 'RUM::AlignIO';

use RUM::Alignment;

sub parse_aln {
    my ($self, $line) = @_;

    my ($readid, $strand, $chr, $loc, $seq) = split /\t/, $line;
    return RUM::Alignment->new(readid => $readid,
                               chr => $chr,
                               loc  => $loc,
                               strand => $strand,
                               seq => $seq,
                               raw => $line);  
}

sub format_aln {
    my ($self, $aln) = @_;
    my @fields = ($aln->readid,
                  $aln->strand,
                  $aln->chromosome,
                  $aln->start,
                  $aln->seq);
    return join("\t", @fields);
}

1;
