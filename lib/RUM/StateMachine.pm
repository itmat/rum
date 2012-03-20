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

    my $start = delete($options{start}) || 0;

    my $self = {};
    $self->{start}        = $start;
    $self->{flags}        = {};
    $self->{transitions}  = {};
    $self->{goal_mask}    = 0;
    return bless $self, $class;
}

sub set_goal {
    my ($self, $mask) = @_;
    $self->{goal_mask} = $mask;
}

sub flag {
    my ($self, $flag) = @_;
    my $n = $self->flags;
    return $self->{flags}{$flag} ||= 1 << $n;
}

sub start {
    shift->{start};
}

sub flags {
    my $self = shift;
    my %flags = %{ $self->{flags} };
    return keys %flags unless @_;
    my $state = shift;
    return grep { $state & $flags{$_} } keys %flags;
}

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

sub add {
    my ($self, $pre, $post, $instruction) = @_;
    $self->{transitions}{$instruction}{$pre} = $post;
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

sub transitions {
    return %{ shift->{transitions} };
}

sub requirements {
    my ($self, $instruction) = @_;
    return keys %{ $self->{transitions}{$instruction} };
}

sub production {
    my ($self, $instruction, $pre) = @_;
    return $self->{transitions}{$instruction}{$pre};
}

sub adjacent {
    my ($self, $state) = @_;

    my %transitions;

    for ($self->instructions) {
        my $new_state = $self->transition($state, $_);
        $transitions{$_} = $new_state unless $new_state == $state;
    }

    return %transitions;
}

sub instructions {
    return keys %{ shift->{transitions} };
}

sub is_goal {
    my ($self, $state) = @_;
    my $goal = $self->{goal_mask};
    return ($state & $goal) == $goal;
}

sub generate {
    my ($self) = @_;

    my @plan;
    my $state = $self->start;

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
1;

__END__


sub state_to_flags {
    my ($self, $state) = @_;

    my @flags;
    for ($self->flags) {
        push @flags, $_ if $state & $self->flags_to_state([$_]);
    }

    return \@flags;
}


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
