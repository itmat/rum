package RUM::CommandMachine;

use strict;
use warnings;
use Carp;
use RUM::StateMachine;
use RUM::Config;
use RUM::Logging;
use Text::Wrap qw(fill wrap);

our $log = RUM::Logging->get_logger;

sub new {
    my ($package, $state_dir) = @_;
    return bless {
        sm => RUM::StateMachine->new(),
        state_dir => $state_dir
    }, $package;
}

sub _filenames_to_bits {
    my ($self, $files) = @_;
    ref($files) =~ /^ARRAY/ or croak 
        "Filenames must be givan as array ref";
    my $bits = 0;
    for my $file (@$files) {
        $bits |= $self->{sm}->flag($file);
    }
    return $bits;
}

sub add_transition {
    my ($self, %options) = @_;

    my $name       = delete $options{instruction};
    my $code       = delete $options{code};
    my $comment    = delete $options{comment};
    my $pre_files  = delete $options{pre};
    my $post_files = delete $options{post};

    my $pre = $self->_filenames_to_bits($pre_files);
    my $post = $self->_filenames_to_bits($post_files);

    $self->{instructions}{$name} = $code;
    $self->{comments}{$name} = $comment;
    $self->{sm}->add($pre, $post, $name);
}

sub start {
    my ($self, $files) = @_;
    my $state = $self->_filenames_to_bits($files);
    $self->state_machine->start($state);
}

sub set_goal {
    my ($self, $files) = @_;
    my $bits = $self->_filenames_to_bits($files);
    return $self->state_machine->set_goal($bits);
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
    my $m = $self->state_machine;
    my $state = 0;

    my @existing_files = grep { -e } $m->flags;

    for (@existing_files) {
        $state |= $m->flag($_);
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

sub commands {
    my ($self, $instruction) = @_;
    $log->debug("Getting commands for instruction $instruction");
    my $code = $self->{instructions}{$instruction} or croak
        "Undefined instruction $instruction";
    ref($code) =~ /^CODE/ or croak "Code for instruction $instruction is not a CODE ref";
    $log->debug("Code is $code");
    my $cmds = $code->();
    return map "@$_", @$cmds;
}

sub state_dir {
    $_[0]->{state_dir};
}

sub shell_script {
    my ($self) = @_;

    my $res;

    my $f = sub {
        my ($sm, $old, $step, $new) = @_;
        my $comment = $self->step_comment($step);
        my @cmds = $self->commands($step);

        # Format the comment
        $comment =~ s/\n//g;
        $comment = fill('# ', '# ', $comment);
        $res .= "$comment\n";
        
        my @post = $sm->flags($new & ~$old);

        if (@post) {
            my @files = @post;
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

    my $sm = $self->state_machine;

    local $_;

    my $f = sub {
        my ($sm, $old, $step, $new) = @_;
        my $comment = $self->step_comment($step);
        my @cmds = $self->commands($step);

        # Format the comment
        $comment =~ s/\n//g;

        my $completed = ($new & $self->state) == $new;

        $callback->($step, $completed) if $callback;

        unless ($completed) {
            for my $cmd (@cmds) {
                my $status = system(@cmds);
                if ($status) {
                    die "Error running $cmd: $!";
                }
                #for ($sm->flags($new & ~$old)) {
                #    open my $file, ">", $_ or die "Can't touch status file $_";
                #    close $file;
                #}
            }
        }

    };

    $self->{sm}->walk($f);
}

sub config {
    $_[0]->{config};
}

1;
