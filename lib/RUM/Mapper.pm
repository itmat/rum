package RUM::Mapper;

use strict;
use warnings;

sub new {
    my ($class, %options) = @_;

    my $self = {};
    $self->{alignments} = delete $options{alignments} || [];
    $self->{source}     = delete $options{source};
    return bless $self, $class;
}

sub alignments {
    my ($self) = @_;
    return $self->{alignments};
}

sub source {
    my ($self) = @_;
    return $self->{source};
}

sub single {
    my ($self) = @_;
    return unless @{ $self->{alignments} } == 1;
    my $aln = $self->{alignments}[0];
    return unless $aln->is_forward || $aln->is_reverse;
    return $aln;
}

sub single_forward {
    my ($self) = @_;
    return unless @{ $self->{alignments} } == 1;
    my $aln = $self->{alignments}[0];
    return unless $aln->is_forward;
    return $aln;
}

sub single_reverse {
    my ($self) = @_;
    return unless @{ $self->{alignments} } == 1;
    my $aln = $self->{alignments}[0];
    return unless $aln->is_reverse;
    return $aln;
}

sub joined {
    my ($self) = @_;
    return unless @{ $self->{alignments} } == 1;
    my $aln = $self->{alignments}[0];
    return $aln if ! ( $aln->is_forward || $aln->is_reverse );
    return;
}

sub unjoined {
    my ($self) = @_;
    return unless @{ $self->{alignments} } == 2;
    return $self->{alignments};
}

sub is_empty {
    my ($self) = @_;
    return ! @{ $self->{alignments} };
}

1;
