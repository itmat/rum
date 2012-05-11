package RUM::BowtieIO;

use strict;
use warnings;

use base 'RUM::AlignIO';

use RUM::Alignment;

sub parse_aln {
    my $self = shift;
    local $_ = shift;

    my ($readid, $strand, $chr, $loc, $seq) = split /\t/;

    return RUM::Alignment->new(-readid => $readid,
                               -chr => $chr,
                               -loc => $loc,
                               -strand => $strand,
                               -seq => $seq);  
}

sub format_aln {
    my ($self, $aln) = @_;
    my @fields = @$aln{qw(readid strand chr loc seq)};
    return join("\t", @fields);
}

1;
