package RUM::CommandMachine;

use strict;
use warnings;
use Carp;
use RUM::StateMachine;
use RUM::Config;
use Text::Wrap qw(fill wrap);

sub new {
    my ($package, $state_dir) = @_;
    return bless {
        sm => RUM::StateMachine->new(),
        state_dir => $state_dir
    }, $package;
}

sub add_transition {
    my ($self, %options) = @_;

    my $name    = delete $options{instruction};
    my $code    = delete $options{code};
    my $comment = delete $options{comment};
    my $pre     = delete $options{pre};
    my $post    = delete $options{post};

    $self->{instructions}{$name} = $code;
    $self->{comments}{$name} = $comment;
    $self->{sm}->add($pre, $post, $name);
}

sub start {
    my ($self, $state) = @_;
    $self->state_machine->start($state);
}

sub flag {
    my ($self, $flag) = @_;
    return $self->state_machine->flag($flag);
}

sub set_goal {
    my ($self, $goal) = @_;
    return $self->state_machine->set_goal($goal);
}

sub step_comment {
    my ($self, $step) = @_;
    return $self->{comments}{$step};
}


sub state_machine {
    return $_[0]->{sm};
}

sub state {
    my ($self) = @_;
    
    local $_;
    my $dir = $self->state_dir;
    my $m = $self->state_machine;
    my $state = 0;

    for ($m->flags) {
        if (-e "$dir/$_") {
            $state |= $m->flag($_);
        }
    }
    return $state;
}

sub state_report {
    my ($self) = @_;

    my $state = $self->state;

    my @report;

    my $callback = sub {
        my ($sm, $old, $step, $new, $comment) = @_;

        my $completed = ($new & $state) == $new;

        push @report, [$completed, $step];

    };
        
    $self->{sm}->walk($callback);
    return @report;
}

sub print_state {
    my ($self) = @_;

    my $state = $self->state;

    my $callback = sub {
        my ($sm, $old, $step, $new, $comment) = @_;
        my $indent = "- ";
        if (($new & $state) == $new) {
            $indent = "X ";
        }
        print(wrap($indent, "  ", $comment), "\n");
    };
        
    $self->{sm}->walk($callback);
}

sub commands {
    my ($self, $instruction) = @_;
    my $code = $self->{instructions}{$instruction} or croak
        "Undefined instruction $instruction";
    my $cmds = $code->();
    return map "@$_", @$cmds;
}

sub state_dir {
    $_[0]->{state_dir};
}

sub shell_script {
    my ($self) = @_;

    my $dir = $self->state_dir;
    mkdir $dir;

    my $res;

    my $f = sub {
        my ($sm, $old, $step, $new) = @_;
        my $comment = $step->step_comment($step);
        my @cmds = $self->commands($step);

        # Format the comment
        $comment =~ s/\n//g;
        $comment = fill('# ', '# ', $comment);
        $res .= "$comment\n";
        
        my @post = $sm->flags($new & ~$old);

        if (@post) {
            my @files = map "$dir/$_", @post;
            my @tests = join(" || ", map("[ ! -e $_ ]", @files));
            $res .= "if @tests; then\n";
            for my $cmd (@cmds) {
                $res .= "  $cmd || exit 1\n";
            }
            $res .= "  touch @files\n";
            $res .= "fi\n";            
        }
        else {
            for my $cmd (@cmds) {
                $res .= "$cmd || exit 1\n";
            }
        }
        $res .= "\n";

    };

    $self->{sm}->walk($f);

    return $res;
}

sub execute {
    my ($self, $callback) = @_;

    my $dir = $self->state_dir;
    my $sm = $self->state_machine;
    mkdir $dir;

    local $_;

    my $f = sub {
        my ($sm, $old, $step, $new) = @_;
        my $comment = $self->step_comment($step);
        my @cmds = $self->commands($step);

        # Format the comment
        $comment =~ s/\n//g;

        my $completed = ($new & $self->state) == $new;

        $callback->($step, $completed);

        unless ($completed) {
            for my $cmd (@cmds) {
                my $status = system(@cmds);
                if ($status) {
                    die "Error running $cmd: $!";
                }
                for ($sm->flags($new & ~$old)) {
                    open my $file, ">", "$dir/$_"
                        or die "Can't touch status file $dir/$_";
                    close $file;
                }
            }
        }

    };

    $self->{sm}->walk($f);
}

sub config {
    $_[0]->{config};
}

1;
