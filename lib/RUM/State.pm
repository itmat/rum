package RUM::State;

=head1 NAME

RUM::State - Represents a state of the workflow.

=head1 DESCRIPTION

TODO: Describe me.

=over 4

=cut

use strict;
use warnings;

=item new(@flags)

Return the state that has all the given flags set.

=cut

sub new {
    my ($class, @flags) = @_;
    my %self = map { ($_ => 1) } @flags;
    return bless \%self, $class;
}


=item union(@states) 

Return the state set that represents the union of my self with all the
given @states.

=cut

sub union {
    my ($self, @others) = @_;
    my %state = %$self;

    for my $other (@others) {
        for my $key (keys %$other) {
            $state{$key} = 1;
        }
    }
    return bless \%state;
}


=item intersect(@states) 

Return the state set that represents the intersection of myself with
all the given @states.

=cut

sub intersect {
    my ($self, @others) = @_;

    my %counts;

    for my $state ($self, @others) {
        for my $key ($state->flags) {
            $counts{$key}++;
        }
    }
    my $n = @others + 1;

    my @flags = grep { $counts{$_} == $n } keys %counts;
    return RUM::State->new(@flags);
}

=item and_not($other)

Return a state containing all the flags set in me bot not in $other.

=cut

sub and_not {
    my ($self, $other) = @_;
    my $result = RUM::State->new;
    for my $flag ($self->flags) {
        $result->set($flag) unless $other->{$flag};
    }
    return $result;    
}

=item flags

Return a list of all the flags set in this state.

=cut

sub flags {
    my $self = shift;
    keys %$self;
}

=item set

Set the given flag.

=cut

sub set {
    my ($self, $flag) = @_;
    $self->{$flag} = 1;
}

=item contains

Return true if other is a subset of me.

=cut

sub contains {
    my ($self, $other) = @_;
    for my $flag ($other->flags) {
        return 0 unless $self->{$flag};
    }
    return 1;
}

=item equals($self, $other)

Returns true if $self and $other represent the same state set.

=cut

sub equals {
    my ($x, $y) = @_;

    my @x_keys = sort keys %$x;
    my @y_keys = sort keys %$y;
    return 0 unless $#x_keys == $#y_keys;
    for my $i (0 .. $#x_keys) {
        return 0 unless $x_keys[$i] eq $y_keys[$i];
    }
    return 1;
}

=item is_empty($state)

Return true if there are no flags set.

=cut

sub is_empty {
    my ($self) = @_;
    ! $self->flags;
}


=item string($state)

Return a string representation of the state.

=cut

sub string {
    my ($self) = @_;
    return join("; ", sort($self->flags));
}

1;

=back
