package RUM::StateMachine;

use strict;
use warnings;
use Exporter qw(import);
use Carp;
use List::Util qw(reduce);
use RUM::Logging;
use Data::Dumper;

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

    $instruction or confess "Instruction can't be false";

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
    my $flags = $self->{flags};
    if (@_) {
        my $state = shift;
        return grep { $state & $flags->{$_} } keys %{ $flags };
    }
    return keys %{ $flags };
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

    $instruction or confess "I was called with an empty instruction";

    my $transitions = $self->{transitions}{$instruction}
        or croak "Unknown instruction $instruction";

    my $to = $from;

    for my $t (@$transitions) {
        
        my ($pre, $post) = @$t;

        # If all the bits in $pre aren't set in $state, then we can't
        # use this transition.
        if (my $missing = $pre & ~$from) {

            $log->trace("transition($from, $instruction) failed, missing ".
                            join(", ", $self->flags($missing))) if $log->is_trace;
            next;
        }
        
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

=item plan

Return a "plan" as a list of instructions that would transition the
machine from the start state to a goal state, or undef if no such
sequence of instructions exists.

=cut

sub plan {
    my ($self) = @_;
    my %seen;
    my @plan;

    my $hit_goal = 0;
    my $callback = sub {
        my ($u, $e, $v) = @_;
        if ($hit_goal) {
            return 0;
        }
        else {
            $hit_goal = $self->is_goal($v);
            push @plan, $e unless $seen{$v}++;
            return 1;
        }
    };

    $self->dfs( $callback ); 

    return \@plan if $hit_goal;
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

    my $u = defined($start) ? $start : $self->start;

    my $plan = $self->plan($start) or 
        $log->warn("Couldn't find a plan for $self"), return 0;

    for my $e (@{ $plan }) {
        my $v = $self->transition($u, $_);
        $callback->($self, $u, $e, $v);
    }
    return 1;
}

=item dfs($callback)

=item dfs($callback, $state)

Do a depth-first search of the state machine starting at $state or the
start state if it's not provided. $callback must be a CODE ref, and it
will be called for each path from one state $u to another state $v
with transition $t, as

  $callback->($u, $t, $v)

=cut

sub dfs {
    my ($self, $callback, $state, $visited, $q) = @_;

    $visited ||= {};
    $q ||= [];
    $state ||= $self->start;

    $visited->{$state} = 1;

    for my $t ($self->instructions) {
        my $new_state = $self->transition($state, $t);
        if ($state != $new_state) {
            my $res = $callback->($state, $t, $new_state);
            last unless $res;
            next if $visited->{$new_state};
            push @$q, $new_state;
            $self->dfs($callback, $new_state, $visited, $q);
        }
    }
}

=item bfs($callback)

=item bfs($callback, $start)

Do a breadth-first search of the state machine starting at $state or
the start state if it's not provided. $callback must be a CODE ref,
and it will be called for each path from one state $u to another state
$v with transition $t, as

  $callback->($u, $t, $v)

I<NOTE>: Be very careful calling this on a large state space.

=cut


sub bfs {
    my $self = shift;
    my $callback = shift;
    my $start = @_ ? shift : $self->start;

    my @q       = ($start);
    my %visited = ($start => undef);

    while (@q) {

        my $u = shift(@q);
        if ($self->is_goal($u)) {
            return 1;
        }
        for my $e ($self->instructions) {
            my $v = $self->transition($u, $e);
            unless (exists $visited{$v}) {
                $callback->($u, $e, $v);
                $visited{$v} = $u;
                push @q, $v;
            }
        }
    }
}

=item minimal_states($plan)

Analyzes the given $plan and returns a list of states, one for each
step of the plan, where the flags for each state are all the flags
that will be set by any subsequent step in the plan. Basically this is
used to keep track of which files we can safely delete depending on
what state we're in. Please see the test file L<t/state-machine.t> for
a more intuitive description.

=cut

sub minimal_states {

    my ($self, $plan) = @_;

    my @states;
    
    $plan ||= $self->plan or return;
    
    my $need = $self->goal_mask;

    for my $e (reverse @{ $plan }) {
        unshift @states, $need;        
        my $transitions = $self->{transitions}{$e} or croak "Unknown step $e";
        
        for my $t (@$transitions) {
            my ($pre, $post) = @$t;
            $need |= $pre;
        }
    }
    return \@states;    
}

=item dotty($fh)

Print a dotty file representing the state machine to the given
filehandle.

=cut

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
        $e =~ s/[-\s,()]/_/g;
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

=item recognize($plan)

=item recognize($plan, $state)

Return true if $plan is a valid plan that will each the goal
state. Uses $state as the start state if it is provided, otherwise the
default start state for this machine.

=cut

sub recognize {
    my $self = shift;
    my @plan = @{ shift || [] };
    my $state = @_ ? shift : $self->start;

    local $_;
    for (@plan) {
        $state = $self->transition($state, $_);
    }
    return $self->is_goal($state);
}

=item skippable($plan)

=item skippable($plan, $state)

Return the number of initial steps of the given plan that can be
skipped, assuming we are starting from the given state.

=cut

sub skippable {
    my $self = shift;
    my @plan = @{ shift || [] };
    my $state = @_ ? shift : $self->start;
    
    # If we're already at the goal we can skip the whole plan.
    return scalar(@plan) if $self->is_goal($state);

    # Otherwise return the largest $i for which we can skip the first
    # $i steps.
    for my $i (reverse (0 .. $#plan)) {
        my @run  = @plan[$i .. $#plan];
        return $i if $self->recognize(\@run, $state);
    }
    return 0;
}

1;

=back

=cut



