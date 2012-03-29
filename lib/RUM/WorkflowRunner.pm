package RUM::WorkflowRunner;

use strict;
use warnings;

our $MAX_STARTS_PER_STATE = 7;
our $MAX_STARTS = 50;

sub new {
    my ($class, $workflow, $code) = @_;
    my $self = {};
    $self->{workflow} = $workflow;
    $self->{code} = $code;
    $self->{starts} = 0;
    $self->{starts_by_state} = {};
    return bless $self, $class;
}

sub times_started {
    my ($self, $state) = @_;
    return $self->{starts_by_state}{$state} || 0 if defined($state);
    return $self->{starts};
}

sub run {
    my ($self) = @_;
    my $state = $self->{workflow}->state;

    return if $self->times_started >= $MAX_STARTS;
    return if $self->times_started($state) >= $MAX_STARTS_PER_STATE;

    $self->{starts_by_state}{$state} ||= 0;
    $self->{starts_by_state}{$state}++;
    $self->{starts}++;
   
    $self->{code}->();
    return 1;
}

sub workflow { $_[0]->{workflow} }
