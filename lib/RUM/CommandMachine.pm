package RUM::CommandMachine;

use strict;
use warnings;

use Carp;
use Text::Wrap qw(fill wrap);
use File::Temp;

use RUM::StateMachine;
use RUM::Config;
use RUM::Logging;

our $log = RUM::Logging->get_logger;

=item new

Return a new RUM::StateMachine.

=cut

sub new {
    my ($class) = @_;
    return bless {
        sm => RUM::StateMachine->new(),
    }, $class;
}

# Given an array ref of filenames, initialize flags for any that I
# don't already know about, and return a bit string representing the
# set of states where all those files exist.
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


# Given a $path (presumably representing a file that affects my
# state), return a temporary filename based on that path.
sub _temp_filename {
    my ($self, $path) = @_;
    my (undef, $dir, $file) = File::Spec->splitpath($path);
    # TODO: Ensure that files will be different for different runs
    my $fh = File::Temp->new(DIR => $dir, TEMPLATE => "$file.XXXXXXXX", UNLINK => 0);
    close $fh;
    return $fh->filename;
}

# Get the temporary filename associated with the given file, or undef
# if there is no associated temp file.
sub _get_temp {
    my ($self, $path) = @_;
    return $self->{temp_files}{$path};
}

=item temp($file)

Return the name of a temporary file, and associate that temp file with
the given $file. Commands should use this to get the name of a file to
write to. After I execute a command, I will copy all temporary files
associated with it to their corresponding non-temporary file.

=cut

sub temp {
    my ($self, $path) = @_;
    $self->{temp_files}{$path} ||= $self->_temp_filename($path);
}

sub add_command {
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
            }
            for ($sm->flags($new & ~$old)) {
                if (my $temp = $self->_get_temp($_)) {
                    -e and $log->warn(
                        "File $_ already exists; ".
                            "I thought it would be created by $step");
                    rename($temp, $_) or croak
                        "Couldn't rename temporary file $temp to $_: $!";
                }
                else {
                    $log->warn("$_ was not first created as a temporary file");
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
