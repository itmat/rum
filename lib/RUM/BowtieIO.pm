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
                               locs => $loc,
                               strand => $strand,
                               seq => $seq,
                               raw => $line);  
}

sub format_aln {
    my ($self, $aln) = @_;
    my @fields = @$aln{qw(readid strand chr loc seq)};
    return join("\t", @fields);
}

1;
