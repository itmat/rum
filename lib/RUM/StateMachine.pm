package RUM::StateMachine;

use strict;
use warnings;
use Exporter qw(import);
use Carp;
use List::Util qw(reduce);

sub is_array_ref_of_strings {
    my ($arg) = @_;
    return ref($arg) =~ /^ARRAY/ && !(grep ref, @$arg);
}


sub new {
    my ($class, %options) = @_;

    for my $key (qw(state_flags instructions start_flags goal_flags)) {
        is_array_ref_of_strings($options{$key}) 
            or croak "$key must be an ARRAY ref of strings";
    }

    my @flags = @{ $options{state_flags} };

    my @instructions = @{ $options{instructions} };

    # Build a hash mapping each flag to its mask
    my %flags;
    my $i;
    for my $flag (@{ $options{state_flags}}) {
        $flags{$flag} = 1 << $i++;
    }

    # Function that takes an array ref of symbols and returns the mask
    # for the set of states that have those flags set.
    my $flags_to_state = sub {
        my ($symbols) = @_;
        my @flags = map { $flags{$_} or croak "Undefined state flag $_" } @$symbols;
        return 0 unless @flags;
        return reduce { $a | $b } @flags;
    };

    my %transitions = map { ($_ => {}) } @instructions;
    
    for my $t (@{ $options{transitions} }) {
        ref($t) =~ /^ARRAY/ or croak "Transition must be an array ref";

        my ($pre, $post, $instruction) = @$t;

        is_array_ref_of_strings($pre) or croak "Precondition must be an array ref, not $post";
        is_array_ref_of_strings($post) or croak "Postcondition must be an array ref, not $post";

        $pre = $flags_to_state->($pre);
        $post = $flags_to_state->($post);

        print "Adding $instruction, $pre, $post\n";

        $transitions{$instruction} or croak "Undefined instruction $instruction";

        $transitions{$instruction}{$pre} = $post;
    }

    my $self = {};
    $self->{flags}          = \@flags;
    $self->{start_state}    = $flags_to_state->($options{start_flags});
    $self->{goal_mask}      = $flags_to_state->($options{goal_flags});
    $self->{transitions}    = \%transitions;
    $self->{flags_to_state} = $flags_to_state;

    return bless $self, $class;
}

sub requirements {
    my ($self, $instruction) = @_;
    return keys %{ $self->{transitions}{$instruction} };
}

sub production {
    my ($self, $instruction, $pre) = @_;
    return $self->{transitions}{$instruction}{$pre};
}

sub transition {
    my ($self, $state, $instruction) = @_;

    my %transitions = $self->transitions();
    for my $pre ($self->requirements($instruction)) {
        my $post = $self->production($instruction, $pre);


        # If all the bits in $pre aren't set in $state, then we can't
        # use this transition.
        next unless ($state & $pre) == $pre;
        
        # If all the bits in $post are already set in $state, this
        # transition would just keep us in the same $state.
        next if ($state & $post) == $post;

        # Otherwise we have a valid transition; the new state is the
        # old $state with all the bits in $post set.
        return $state | $post;
    }
    
    return $state;
}

sub adjacent {
    my ($self, $state) = @_;

    my %transitions;

    for ($self->instructions) {
        my $new_state = $self->transition($state, $_);
        $transitions{$_} = $new_state unless $new_state == $state;
        print "Adding $_ => $new_state\n";
    }

    return %transitions;
}

sub is_goal {
    my ($self, $state) = @_;
    my $goal = $self->{goal_mask};
    return ($state & $goal) == $goal;
}

sub generate {
    my ($self) = @_;

    my @plan;
    my $state = $self->start_state;

    while (!$self->is_goal($state)) {

        # Map from instruction to the state I'd reach if I executed it
        my %adj = $self->adjacent($state);

        my @instructions = sort keys %adj;
        return undef unless @instructions;

        my $instruction = $instructions[0];
        push @plan, $instruction;
        $state = $adj{$instruction};
    }
    return \@plan;
}

sub flags_to_state {

    my $self = shift;

    my $flags = @_ == 1 && ref($_[0]) =~ /^ARRAY/ ? shift : [@_];
    
    return $self->{flags_to_state}->($flags);
}

sub flags {
    return @{ shift->{flags} };
}

sub instructions {
    return keys %{ shift->{transitions} };
}

sub transitions {
    return %{ shift->{transitions} };
}

sub start_state {
    return shift->{start_state};
}

sub state_to_flags {
    my ($self, $state) = @_;

    my @flags;
    for ($self->flags) {
        push @flags, $_ if $state & $self->flags_to_state([$_]);
    }

    return \@flags;
}

1;
__END__

sub to_makefile {
    my ($self, @args) = @_;

    my @plan = $self->generate($self->{start_state});

    $self->run(sub { push @plan, @_ }, @args);

    my $dir = $self->{state_dir};
    my @to = map "$dir/$_", @{ $self->goal_flags };

    my $res = "all : @$to\n\n";

    for my $step (@plan) {

        my @requires = map  "$dir/$_", $step->requires;
        my @produces = map  "$dir/$_", $step->produces;

        $res .= "\n@produces : @requires\n";
        for my $cmd (@{ $step->action->(@args) }) {
            $res .= "\t@$cmd\n"
        }
        for my $new_state ($step->produces) {
            $res .= "\ttouch $self->{state_dir}/$new_state\n";
        }
    }
    return $res;
}

sub shell_script {
    my ($self) = @_;
    my $res = "\n";
    $res .= "# Requires " . join(", ", $self->requires) . "\n";
    $res .= "# Produces " . join(", ", $self->produces) . "\n";
    for my $cmd ($self->action) {
        $res .= "@$cmd\n";
    }
    return $res;
}

1;
