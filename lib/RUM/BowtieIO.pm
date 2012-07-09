package RUM::BowtieIO;

use strict;
use warnings;

use base 'RUM::AlignIO';

use RUM::Alignment;

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(%options);
    $self->{strand_last} = $options{strand_last};
    return $self;
}

sub parse_aln {
    my ($self, $line) = @_;

    my @fields = split /\t/, $line;
    my ($readid, $strand, $chr, $loc, $seq) = @fields;

    if ($self->{strand_last}) {
        ($readid, $chr, $loc, $seq, $strand) = @fields;
    }

    if ($loc =~ /-/) {
        my $locs = [ map { [split /-/] } split /,\s*/, $loc ];
        return RUM::Alignment->new(readid => $readid,
                                   chr => $chr,
                                   locs  => $locs,
                                   strand => $strand,
                                   seq => $seq,
                                   raw => $line);  
    }

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
