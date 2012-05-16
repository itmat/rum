package RUM::AlignIO;

use strict;
use warnings;
use autodie;

use Carp;

use RUM::Alignment;

use base 'RUM::BaseIO';

sub next_aln {

    my ($self) = @_;

    my $fh = $self->{fh};
    local $_ = <$fh>;
    defined or return;
    chomp;
    return $self->parse_aln($_);
}

sub write_aln {
    my ($self, $aln) = @_;
    my $fh = $self->{fh};
    print $fh $self->format_aln($aln), "\n";
}

sub iterator {
    my $self = shift;
    return RUM::Iterator->new(sub { $self->next_aln });
}



1;
