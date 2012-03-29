package RUM::CommandMachine;

use strict;
use warnings;

use Carp;
use Text::Wrap qw(fill wrap);
use File::Temp;

use RUM::StateMachine;
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

=item add_command(%options)

Add a command. The following options must be specified:

=over 4

=item B<name>

The name for the command.

=item B<comment>

A short description of the command.

=item B<pre>

Array ref of files that must exist before the command is run.

=item B<post>

Array ref of files that will exist after the command is run.

=item B<code>

A code ref that, when run, returns an array ref of commands to
execute on the shell.

=back

=cut

sub add_command {
    my ($self, %options) = @_;

    my $name       = delete $options{name};
    my $code       = delete $options{code};
    my $comment    = delete $options{comment};
    my $pre_files  = delete $options{pre};
    my $post_files = delete $options{post};

    my $pre = $self->_filenames_to_bits($pre_files);
    my $post = $self->_filenames_to_bits($post_files);

    $self->{commands}{$name} = $code;
    $self->{comments}{$name} = $comment;
    $self->{sm}->add($pre, $post, $name);
}

=item start($files)

Set the start state for this machine, as a set of files that exist
before the machines starts. $files must be an array ref of paths.

=cut

sub start {
    my ($self, $files) = @_;
    my $state = $self->_filenames_to_bits($files);
    $self->state_machine->start($state);
}

=item set_goal($files)

Set the goal state for this machine, as a set of files that must exist
after the machine stops. $files must be an array ref of paths.

=cut

sub set_goal {
    my ($self, $files) = @_;
    my $bits = $self->_filenames_to_bits($files);
    return $self->state_machine->set_goal($bits);
}

=item comment

Return the comment associated with the command that has the given $name.

=cut

sub comment {
    my ($self, $name) = @_;
    return $self->{comments}{$name};
}

=item state_machine

Return the state machine for this workflow.

=cut

sub state_machine {
    return $_[0]->{sm};
}

=item state

Return the current state of the workflow as a bit string. Determines
the state by checking to see which files exist.

=cut

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

sub walk_states {

    my ($self, $callback) = @_;

    my $state = $self->state;

    my $f = sub {
        my ($sm, $old, $name, $new) = @_;
        my $completed = ($new & $state) == $new;
        $callback->($name, $completed);
    };
        
    $self->{sm}->walk($f);

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
    my ($self, $name) = @_;
    $log->debug("Getting commands for name $name");
    my $code = $self->{commands}{$name} or croak
        "Undefined command $name";
    ref($code) =~ /^CODE/ or croak "Code for command $name is not a CODE ref";
    $log->debug("Code is $code");
    my $cmds = $code->();
    return map "@$_", @$cmds;
}

sub shell_script {
    my ($self) = @_;

    my $res;

    my $f = sub {
        my ($sm, $old, $step, $new) = @_;
        my $comment = $self->comment($step);
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

=item execute($callback)

Execute the sequence of commands necessary to bring the workflow from
its current state to a goal state. You can provide a callback function
in order to get an update before each command is executed. $callback
(if provided) will be called in the following manner:

  $callback->($name, $completed)

Where $name is the name of the command, and $completed is true if the
command will be skipped because it postconditions are already
satisfied.

=cut

sub execute {
    my ($self, $callback) = @_;

    my $sm = $self->state_machine;

    local $_;

    my $f = sub {
        my ($sm, $old, $step, $new) = @_;
        my $comment = $self->comment($step);
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

1;
