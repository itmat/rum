package RUM::StateMachine;

use strict;
use warnings;
use Exporter qw(import);
use Carp;
use List::Util qw(reduce);

=head1 NAME

RUM::StateMachine - DFA for modeling state of RUM jobs.

=cut

=head1 CONSTRUCTORS

=over 4

=item $machine = RUM::StateMachine->new

=item $machine = RUM::StateMachine->new(start => $state)

Create a new state machine, optionally with a start state (it defaults
to 0).

=cut

sub new {
    my ($class, %options) = @_;

    my $start = delete($options{start}) || 0;

    my $self = {};
    $self->{start}        = $start;
    $self->{flags}        = {};
    $self->{transitions}  = {};
    $self->{goal_mask}    = 0;
    return bless $self, $class;
}

=back

=head1 METHODS

=head2 Setup

These methods are all involved in setting up the machine.

=over 4

=item set_goal($mask)

Set the mask for the goal. The state machine is in a final state
$state all the bits in $mask are set.

=cut

sub set_goal {
    my ($self, $mask) = @_;
    $self->{goal_mask} = $mask;
}

=item flag($flag)

Return the bit string for the given flag, creating the flag if it
doesn't exist.

=cut

sub flag {
    my ($self, $flag) = @_;
    my $n = $self->flags;
    return $self->{flags}{$flag} ||= 1 << $n;
}

=item add($comment, $pre, $post, $instruction)

=item add($pre, $post, $instruction)

When three arguments are given, add a transition from each state $s
where the $pre flags are set to the state $s | $post; that is, when
in a state where all the $pre flags are set, I can set all the
$post flags by applying the given $instruction.

When four arguments are given, the first should be a descriptive
comment, which will be associated with this transition. 

=cut

sub add {
    my $self = shift;
    my $comment = @_ == 4 ? shift : "";
    my ($pre, $post, $instruction) = @_;
    $self->{transitions}{$instruction} ||= [];
    push @{ $self->{transitions}{$instruction} },
        [$pre, $post, $comment];
}

=back

=head2 Operation

=over 4

=item start

Return the start state of this machine.

=cut

sub start {
    shift->{start};
}

=item instructions

Return the list of all instructions

=cut

sub instructions {
    return keys %{ shift->{transitions} };
}

=item flags

=item flags($state)

With no arguments, return a list of all the symbolic flags for this
state machine. Note that if there are n flags, the full state set of
this machine contains 2^n states. This is generally too many to deal
with, and most of those states aren't interesting. When we set up a
machine, rather than enumerate all states, we instead set up
transitions to and from sets of states, referring to each set by the
flags that are present in those states.

With a $state argument, return a list of all the symbolic flags that
are set in that state.

=cut

sub flags {
    my $self = shift;
    my %flags = %{ $self->{flags} };
    return keys %flags unless @_;
    my $state = shift;
    return grep { $state & $flags{$_} } keys %flags;
}

=item state(@flags)

Given a list of @flags, return the state represented by all those
flags being set.

=cut

sub state {
    my ($self, @flags) = @_;
    my $state = 0;
    for my $flag (@flags) {
        my $bit = $self->{flags}{$flag}
            or croak "Undefined flag $flag";
        $state |= $bit;
    }
    return $state;
}

=item transition($state, $instruction)

Return the state that would result from applying $instruction when in
state $state.

  my $new_state = $machine->transition($state, $instruction);

=cut

sub transition {
    my ($self, $from, $instruction) = @_;

    my $transitions = $self->{transitions}{$instruction}
        or croak "Unknown instruction $instruction";

    my $to = $from;

    for my $t (@$transitions) {
        
        my ($pre, $post, $comment) = @$t;

        # If all the bits in $pre aren't set in $state, then we can't
        # use this transition.
        next unless ($from & $pre) == $pre;
        
        $to = $from | $post;

        # If all the bits in $post are already set in $state, this
        # transition would just keep us in the same $state.
        next if $to == $from;

        # Otherwise we have a valid transition; the new state is the
        # old $state with all the bits in $post set.
        return wantarray ? ($to, $comment) : $to;
    }
    
    return wantarray ? ($from, "") : $from;
}

sub _requirements {
    my ($self, $instruction) = @_;
    return keys %{ $self->{transitions}{$instruction} };
}

sub _production {
    my ($self, $instruction, $pre) = @_;
    return $self->{transitions}{$instruction}{$pre};
}

sub _adjacent {
    my ($self, $state) = @_;

    my %transitions;

    for ($self->instructions) {
        my $new_state = $self->transition($state, $_);
        $transitions{$_} = $new_state unless $new_state == $state;
    }

    return %transitions;
}

=item is_goal($state)

Return true if the given $state is a goal state, false otherwise.

=cut

sub is_goal {
    my ($self, $state) = @_;
    my $goal = $self->{goal_mask};
    return ($state & $goal) == $goal;
}

=item generate

Return a "plan" as a list of instructions that would transition the
machine from the start state to a goal state, or undef if no such
sequence of instructions exists.

=cut

sub generate {
    my ($self) = @_;

    my @plan;
    my $state = $self->start;

    while (!$self->is_goal($state)) {

        # Map from instruction to the state I'd reach if I executed it
        my %adj = $self->_adjacent($state);

        my @instructions = sort keys %adj;
        return undef unless @instructions;

        my $instruction = $instructions[0];
        push @plan, $instruction;
        $state = $adj{$instruction};
    }
    return \@plan;
}

1;

=back

=cut



