package RUM::Workflow;

use strict;
use warnings;

use Carp;
use Text::Wrap qw(fill wrap);
use File::Temp;

use RUM::StateMachine;
use RUM::Logging;

use Exporter qw(import);
our @EXPORT_OK = qw(pre post);

our $log = RUM::Logging->get_logger;


=head1 NAME

RUM::Workflow - Generic library for specifying a workflow as a
sequence of commands

=head1 SYNOPSIS

  use RUM::Workflow;

  my $wf = RUM::Workflow->new();

  $wf->add_command(
      name => "do_stuff",
      comment => "This command does things",
      pre => ..., # Files that must exist before I run
      post => ..., # Files that I will create
      commands => ... # CODE ref that returns commands to run
  );

  ... # Add more commands

=head1 CONSTRUCTORS

=over 4

=item new

Return a new RUM::Workflow.

=back

=cut

sub new {
    my ($class) = @_;
    return bless {
        sm => RUM::StateMachine->new(),
    }, $class;
}

=head1 METHODS

=head2 Building the Workflow

=over 4

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

=item B<commands>

A code ref that, when run, returns an array ref of commands to
execute on the shell.

=back

=cut

sub add_command {
    my ($self, %options) = @_;

    my $name       = delete $options{name};
    my $commands   = delete $options{commands};
    my $comment    = delete $options{comment};
    my $pre_files  = delete $options{pre};
    my $post_files = delete $options{post};

    my @cmds;

    if (ref($commands) =~ /^ARRAY/) {
        for my $cmd (@$commands) {
            my @parts;
            for my $part (@$cmd) {
                if (ref($part) =~ /^HASH/) {
                    if (my $file = $part->{pre}) {
                        push @$pre_files, $file;
                        push @parts, $file;
                    }
                    elsif ($file = $part->{post}) {
                        push @$post_files, $file;
                        push @parts, $self->temp($file);
                    }
                }
                else {
                    push @parts, $part;
                }
            }
            push @cmds, \@parts;
        }
        @$commands = @cmds;
    }

    $name or croak "Each command needs a name";

    my $pre = $self->_filenames_to_bits($pre_files || []);
    my $post = $self->_filenames_to_bits($post_files || []);

    $self->{commands}{$name} = $commands;
    $self->{comments}{$name} = $comment;
    $self->{sm}->add($pre, $post, $name);
}

=item step($name, @commands)

Creates a step with the given name and commands.

=cut

sub step {
    my ($self, $name, @commands) = @_;
    $self->add_command(name => $name, commands => \@commands);
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

=item start($files)

Set the start state for this machine, as a set of files that exist
before the machines starts. $files must be an array ref of paths.

=cut

sub start {
    my ($self, $files) = @_;
    my $state = $self->_filenames_to_bits($files);
    $log->debug("My start files are @$files, state is $state");
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

=back

=head2 Accessing a Workflow

=over 4

=item comment

Return the comment associated with the command that has the given $name.

=cut

sub comment {
    my ($self, $name) = @_;
    return $self->{comments}{$name} || $name;
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

=item walk_states

Walk the path of states from the current state to a goal state,
calling $callback for each command necessary to transition us to the
goal state.

=cut

sub walk_states {

    my ($self, $callback) = @_;

    my $state = $self->state;

    my $f = sub {
        my ($sm, $old, $name, $new) = @_;
        my $completed = ($new & $state) == $new;
        $log->debug("In state $old".
                        ($completed ? " (completed)" : "").
                            ", using $name to get to $new");
        $callback->($name, $completed);
    };
        
    $self->{sm}->walk($f) or $log->warn("Hit a dead end");
    
}

=item all_commands($name)

Return the names of all the steps on the path from the current state
to a goal state.

=cut

sub all_commands {
    my ($self) = @_;
    my @commands;
    my $f = sub {
        my ($name, $completed) = @_;
        push @commands, $name;
    };
    $self->walk_states($f);
    return @commands;
}

=item commands($name)

Return the shell commands with the given name.

=cut

sub commands {
    my ($self, $name) = @_;
    $log->debug("Getting commands for name $name");
    my $commands = $self->{commands}{$name} or croak
        "Undefined command $name";

    $commands = $commands->() if ref($commands) =~ /^CODE/;

    ref($commands) =~ /^ARRAY/ or croak
        "Commands must be an array ref, not $commands";

    return @$commands;
}

=item shell_script($filehandle)

Print the workflow as a shell script to the given $filehandle

=cut

sub shell_script {
    my ($self, $fh) = @_;

    my $f = sub {
        my ($sm, $old, $step, $new) = @_;
        my $comment = $self->comment($step);
        my @cmds = $self->commands($step);

        # Format the comment
        $comment =~ s/\n//g;
        $comment = fill('# ', '# ', $comment);
        print $fh  "$comment\n";
        
        my @post = $sm->flags($new & ~$old);

        if (@post) {
            my @files = @post;
            my @tests = join(" || ", map("[ ! -e $_ ]", @files));
            print $fh  "if @tests; then\n";
            for my $cmd (@cmds) {
                print $fh  "  $cmd || exit 1\n";
            }
            print $fh  "  touch @files\n";
            print $fh  "fi\n";            
        }
        else {
            for my $cmd (@cmds) {
                print $fh  "$cmd || exit 1\n";
            }
        }
        print $fh  "\n";

    };

    $self->{sm}->walk($f);
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

    $sm->start($self->state);
    $log->debug("Executing workflow");
    my $f = sub {
        my ($sm, $old, $step, $new) = @_;
        $log->debug("  at step $old,  $step,  $new");
        my $comment = $self->comment($step);
        my @cmds = $self->commands($step);

        # Format the comment
        $comment =~ s/\n//g;

        my $completed = ($new & $self->state) == $new;

        $callback->($step, $completed) if $callback;

        unless ($completed) {
            for my $cmd (@cmds) {
                $log->debug("Running @$cmd");

                my $stdout;
                my $stdout_mode;
                my @from = @ { $cmd };
                my @to;
                while (local $_ = shift @from) {
                    if (/\s*(>>|>)\s*/){
                        $stdout = shift(@from);
                        $stdout_mode = $1;
                    }
                    else {
                        push @to, $_;
                    }
                }

                if (my $pid = fork) {

                    my $oldhandler = $SIG{TERM};

                    $SIG{TERM} = sub {
                        warn("Caught SIGTERM, killing child process ($to[0])");
                        kill 15, $pid;
                        waitpid $pid, 0;
                        RUM::Lock->release;
                        $oldhandler->(@_) if $oldhandler;
                        die;
                    };
                    
                    waitpid($pid, 0);
                    $SIG{TERM} = $oldhandler;

                    if ($?) {
                        die "Error running @$cmd: $!";
                    }                    
                }
                else {
                    if ($stdout) {
                        close STDOUT;
                        open STDOUT, $stdout_mode, $stdout or croak "Can't open output $stdout: $!";
                    }
                    exec(@to);
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
            
            my $state = $self->state;
            
            if ($new != $state) {
                my @missing = $sm->flags($new & ~$state);
                my @extra   = $sm->flags($state & ~$new);
                $log->warn("I am not in the state I'm supposed to be. I am missing @missing and have extra files @extra");
            }
        }

    };

    $self->{sm}->walk($f);
}

=item is_complete

Return a true value if the current state is a goal state, false
otherwise.

=cut

sub is_complete {
    my ($self) = @_;
    my $goal = $self->state_machine->goal_mask;
    my $state = $self->state;
    return ($goal & ~$state) == 0;
}

# Given an array ref of filenames, initialize flags for any that I
# don't already know about, and return a bit string representing the
# set of states where all those files exist.
sub _filenames_to_bits {
    my ($self, $files) = @_;
    ref($files) =~ /^ARRAY/ or croak 
        "Filenames must be given as array ref";
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
    my $fh = File::Temp->new(DIR => $dir, TEMPLATE => "_tmp_$file.XXXXXXXX", UNLINK => 1);
    close $fh;
    return $fh->filename;
}

# Get the temporary filename associated with the given file, or undef
# if there is no associated temp file.
sub _get_temp {
    my ($self, $path) = @_;
    return $self->{temp_files}{$path};
}

sub pre { {pre => shift} }
sub post { {post => shift} }


=item clean($clean_goal)

Removes files created by all intermediate states, not required by a
goal state. If $clean_goal is true, removes all goal files as well.

=cut

sub clean {
    my ($self, $clean_goal) = @_;
    $log->debug("Cleaning up");
    local $_;

    if ($clean_goal) {
        for ($self->state_machine->flags()) {
            $log->debug("veryclean: removing $_");
            unlink;
        }        
    }
    else {
        my $state = $self->state;
        my $goal = $self->state_machine->goal_mask;
        my $extra_bits = $state & ~$goal;
        for ($self->state_machine->flags($extra_bits)) {
            $log->debug("clean: removing $_");
            unlink;
        }
    }
}

1;
