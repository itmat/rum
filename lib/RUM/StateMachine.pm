package RUM::StateMachine;

use strict;
use warnings;
use Exporter qw(import);
use Carp;
use List::Util qw(reduce);
use RUM::Logging;

our $log = RUM::Logging->get_logger;

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

=item add($pre, $post, $instruction)

=item add($pre, $post, $instruction)

When three arguments are given, add a transition from each state $s
where the $pre flags are set to the state $s | $post; that is, when
in a state where all the $pre flags are set, I can set all the
$post flags by applying the given $instruction.

=cut

sub add {
    my $self = shift;
    my ($pre, $post, $instruction) = @_;
    $self->{transitions}{$instruction} ||= [];
    push @{ $self->{transitions}{$instruction} },
        [$pre, $post];
}

=back

=head2 Operation

=over 4

=item start

Return the start state of this machine.

=cut

sub start {
    my ($self, $start) = @_;
    $self->{start} = $start if defined $start;
    $self->{start};
}

=item instructions

Return the list of all instructions

=cut

sub instructions {
    return sort keys %{ shift->{transitions} };
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
        
        my ($pre, $post) = @$t;

        # If all the bits in $pre aren't set in $state, then we can't
        # use this transition.
        next unless ($from & $pre) == $pre;
        
        $to = $from | $post;

        # If all the bits in $post are already set in $state, this
        # transition would just keep us in the same $state.
        next if $to == $from;

        # Otherwise we have a valid transition; the new state is the
        # old $state with all the bits in $post set.
        return $to;
    }
    
    return $from;
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

=item goal_mask

Return the bits that need to be set for a goal state

=cut

sub goal_mask { $_[0]->{goal_mask} };


=item is_goal($state)

Return true if the given $state is a goal state, false otherwise.

=cut

sub is_goal {
    my ($self, $state) = @_;
    my $goal = $self->goal_mask;
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

    my $append = sub {
        my ($self, $old, $instruction, $new) = @_;
        push @plan, $instruction;
    };

    $self->walk($append);
    return \@plan;
}

=item walk($callback)

Walk the sequence of transitions necessary to bring this state machine
from its start state to a goal state, calling $callback for each
transition.  $callback is called as follows

  $callback->($self, $state, $instruction, $new_state, $comment);

Where $self is this state machine, $state is the state before the
given $instruction would be applied, and $new_state is the state after
$instruction was applied.

=cut

sub walk {
    my ($self, $callback, $start) = @_;

    my $state = defined($start) ? $start : $self->start;
    
  STATE: while (!$self->is_goal($state)) {
        $log->debug("Looking at state $state");
        local $_;
        for (sort($self->instructions)) {

            my $new_state = $self->transition($state, $_);
            $log->debug("$_ at $state yields $new_state");
            if ($new_state != $state) {
                $callback->($self, $state, $_, $new_state);
                $state = $new_state;
                next STATE;
            }
        }
        $log->warn("Couldn't find a plan for $self");
        return 0;
    }
    return 1;
}


sub dfs {
    my ($self, $callback, $state, $visited, $q) = @_;

    $visited ||= {};
    $q ||= [];
    $state ||= $self->start;

    $visited->{$state} = 1;

    for my $t ($self->instructions) {
        my $new_state = $self->transition($state, $t);
        if ($state != $new_state) {
            $callback->($state, $t, $new_state);
            next if $visited->{$new_state};
            push @$q, $new_state;
            $self->dfs($callback, $new_state, $visited, $q);
        }
    }
}

sub dotty {
    my ($self, $fh) = @_;

    my %nodes;
    my @edges;
    my %instructions;

    my $visit = sub {
        push @edges, [@_];
        $nodes{$_[0]} = 1;
        $instructions{$_[1]} = 1;
        $nodes{$_[2]} = 1;
    };
    $self->dfs($visit);

    print $fh "digraph states {\n";

    for my $node (sort keys %nodes) {
        if ($self->is_goal($node)) {
            print $fh "  $node [shape=doublecircle];\n";
        }
    }

    for my $edge (@edges) {
        my ($u, $e, $v) = @$edge;
        $e =~ s/[-\s]/_/g;
        print $fh "  $u -> $v [label=$e];\n";
    }

    print $fh "}\n";

    for my $inst ($self->instructions) {
        next if $instructions{$inst};

        warn "Instruction '$inst' is not used:\n";
        for my $pre_post (@{ $self->{transitions}{$inst} }) {
            my ($pre, $post) = @$pre_post;
            warn "  $pre\n";
        }
        
        
    }
}

1;

=back

=cut



