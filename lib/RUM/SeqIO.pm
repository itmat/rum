package RUM::SeqIO;

use strict;
use warnings;
use autodie;

use Carp;
use RUM::Sequence;

use base 'RUM::BaseIO';

sub next_seq {

    my ($self) = @_;
    my $fh = $self->{fh};
    my $header = <$fh>;
    return unless defined $header;

    chomp $header;

    my $seq = <$fh>;
    chomp $seq;
    return RUM::Sequence->new(
        readid => substr($header, 1),
        seq    => $seq);
}

sub write_seq {
    my ($self, $seq) = @_;
    my $fh = $self->{fh};
    printf $fh ">%s\n%s\n", $seq->readid, $seq->seq;
}

1;
