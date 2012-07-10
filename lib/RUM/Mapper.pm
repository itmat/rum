package RUM::Mapper;

use strict;
use warnings;

sub new {
    my ($class, %options) = @_;

    my $self = {};
    $self->{alignments} = delete $options{alignments} || [];
    return bless $self, $class;
}

sub alignments {
    my ($self) = @_;
    return $self->{alignments};
}

sub is_single {
    my ($self) = @_;
    return unless @{ $self->{alignments} } == 1;
    my $aln = $self->{alignments}[0];
    return $aln->is_forward || $aln->is_reverse;
}

sub is_joined {
    my ($self) = @_;
    return unless @{ $self->{alignments} } == 1;
    my $aln = $self->{alignments}[0];
    return ! ( $aln->is_forward || $aln->is_reverse );
}

sub is_unjoined {
    my ($self) = @_;
    return @{ $self->{alignments} } == 2;
}

sub is_empty {
    my ($self) = @_;
    return ! @{ $self->{alignments} };
}

1;
