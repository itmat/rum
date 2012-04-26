package RUM::WorkflowRunner;

use strict;
use warnings;

our $MAX_STARTS_PER_STATE = 7;
our $MAX_STARTS = 50;

=head1 NAME

RUM::WorkflowRunner - Manage restart information for a workflow

=head2 CONSTRUCTORS

=over 4

=item new($workflow, $code)

Create a RUM::WorkflowRunner that runs the given $code, associated
with the given workflow.

=cut

sub new {
    my ($class, $workflow, $code) = @_;
    my $self = {};
    $self->{workflow} = $workflow;
    $self->{code} = $code;
    $self->{starts} = 0;
    $self->{starts_by_state} = {};
    return bless $self, $class;
}

=item times_started

With the $state argument, return the number of times this I was run in
the given $state. Without the $state argument, return the total number
of times I was started.

=cut

sub times_started {
    my ($self, $state) = @_;
    return $self->{starts_by_state}{$state->string} || 0 if defined($state);
    return $self->{starts};
}

=item run

Run the $code I was constructed with, unless I have run it more than
$MAX_STARTS_PER_STATE times in the current state of the workflow, or
more than $MAX_STARTS times total.

=cut

sub run {
    my ($self) = @_;
    my $state = $self->{workflow}->state;

    return if $self->times_started >= $MAX_STARTS;
    return if $self->times_started($state) >= $MAX_STARTS_PER_STATE;

    $self->{starts_by_state}{$state->string} ||= 0;
    $self->{starts_by_state}{$state->string}++;
    $self->{starts}++;
   
    $self->{code}->();
    return 1;
}

=item workflow

Return the workflow associated with this object.

=cut

sub workflow { $_[0]->{workflow} }
