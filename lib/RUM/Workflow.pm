package RUM::Workflow;

use strict;
use warnings;
use autodie;

use Carp;
use Text::Wrap qw(fill wrap);
use File::Temp;
use File::Path qw(mkpath);

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
    my ($class, %params) = @_;
    my $name = delete $params{name};
    return bless {
        sm => RUM::StateMachine->new(),
        name => $name
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

Return the function which, when executed, returns name of a temporary
file, and associates that temp file with the given $file. Commands
should use this to get the name of a file to write to. After I execute
a command, I will copy all temporary files associated with it to their
corresponding non-temporary file.

Note that this returns a function so that we "lazily" allocate
temporary files. Calling File::Temp->new can be very expensive. This
accounted for quite a lot of time when just checking the status of a
job.

=cut

sub temp {
    my (undef, $path) = @_;

    return sub { 
        my $self = shift;
        $self->{temp_files}{$path} ||= $self->_temp_filename($path);
    };
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

    return $m->state(@existing_files);
}

=item walk_states

Walk the path of states from the current state to a goal state,
calling $callback for each command necessary to transition us to the
goal state.

=cut

sub walk_states {

    my ($self, $callback) = @_;

    my $u = $self->state;
    my $sm = $self->state_machine;
    my $plan = $sm->plan or confess "No plan";
    for my $e (@{ $plan }) {
        my $v = $sm->transition($u, $e);
        my $completed = $u->contains($v) ? " (completed)" : "";
        $log->debug("In state $u$completed, using $e to get to $v");
        $callback->($e, $completed);
    }
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

    my @result;
    for my $parts (@$commands) {
        my @parts = map { ref($_) =~ /CODE/ ? $_->($self) : $_ } @$parts;
        push @result, \@parts;
    }
    return @result;
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
        
        my @post = $new->and_not($old)->flags;

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

sub _run_step {

    my ($self, $old, $step, $new) = @_;

    local $_;

    my $sm = $self->state_machine;
    my $comment = $self->comment($step);
    my @cmds = $self->commands($step);
    
    # Format the comment
    $comment =~ s/\n//g;

    $log->info("START\t$step");
    
    for my $cmd (@cmds) {
            
        my $stdout;
        my $stdout_mode;
        my @from = @ { $cmd };
        my @to;
      ARG: while (@from) {
            my $arg = shift @from;
            next ARG unless defined($arg);
            if ($arg =~ /\s*(>>|>)\s*/){
                $stdout = shift(@from);
                $stdout_mode = $1;
            }
            else {
                push @to, $arg;
            }
        }

        # If the command didn't explicitly redirect its output, append
        # it to a file right next to our log file, but named *.out
        # instead of *.log
        unless ($stdout) {
            if ($stdout = $RUM::Logging::LOG_FILE) {
                $stdout =~ s/log$/out/;
                $stdout_mode = ">>";
            }
        }

        # Before we fork, get a temporary file name for the child
        # process to write its stderr to. If it fails we'll read this
        # in and log it.
        my $err_fh = File::Temp->new(UNLINK => 1);
        my $err_fname = $err_fh->filename;
        close $err_fh;

        if (my $pid = fork) {
            
            my $oldhandler = $SIG{TERM};
            
            $SIG{TERM} = sub {
                my $msg = "Caught SIGTERM, killing current task, waiting for it, and removing lock.";
                warn $msg;
                $log->info($msg);
                kill 15, $pid;
                waitpid $pid, 0;
                RUM::Lock->release;
                $oldhandler->(@_) if $oldhandler;
                die;
            };
            
            waitpid($pid, 0);
            $SIG{TERM} = $oldhandler;

            if ($?) {
                # The stderr from the child process should have been
                # redirected here.
                my @errors = eval {
                    open my $error_fh, "<", $err_fname;
                    (<$error_fh>);
                };

                my $msg = "\nError running \"@$cmd\"\n\n";
                if (@errors) {
                    $msg .= "The stderr from that command is\n\n";
                    $msg .= join("", map("> $_", @errors)) . "\n";
                }
                else {
                    $msg .= "The command had no stderr output.\n\n";
                }
                $msg .= "The error log file $RUM::Logging::ERROR_LOG_FILE may have more details.\n";
                die $msg;
            }                    
        }
        else {
            if ($stdout) {
                close STDOUT;
                open STDOUT, $stdout_mode, $stdout or croak "Can't open output $stdout: $!";
            }
            close STDERR;

            # This will redirect my (the child's) output to the temp
            # file obtained above.

            open STDERR, ">", $err_fname;
            $log->info("EXEC\t@to");
            exec(@to) or die(
                "Couldn't exec '@to': $!\n" .
                "This probably means that the program $to[0] doesn't exist " .
                "or isn't executable");
        }
    }
    $log->info("FINISH\t$step");
    for ($new->and_not($old)->flags) {

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
    
    unless ($new->equals($state)) {
        my @missing = $new->and_not($state)->flags;
        my @extra   = $state->and_not($new)->flags;
        $log->warn("I am not in the state I'm supposed to be. I am missing @missing and have extra files @extra");
    }
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
    my ($self, $callback, $clean) = @_;
    my $wf_name = $self->{name} || '';
    $log->info("Starting workflow '$wf_name'. I will " .
               ($clean ? " " : " not") .
               "clean up intermediate temporary files along the way.");

    local $_;
    my $sm    = $self->state_machine;
    my $state = $self->state;
    my $plan = $sm->plan or confess "No plan";
    my $missing = $sm->start->and_not($state);

    my $skip = $sm->skippable($plan, $state);
    my @plan = @{ $plan };
    $sm->recognize($plan, $sm->start) or croak "Error, can't build a plan";
    my $min_states = $sm->minimal_states($plan);

    my $count = 0;

    for my $step (@plan) {

        # If I've already done this step, skip it. Calling the
        # callback with a true second arg indicates that I skipped it.
        if ($count < $skip) {
            $callback->($step, 1) if $callback;
        }
        
        else {
            $callback->($step, 0) if $callback;
            my $state = $self->state;
            my $next_state = $sm->transition($state, $step);
            $self->_run_step($state, $step, $next_state);
        }

        # These are the files I will need going forward
        my $need = $min_states->[$count]->union($sm->start);

        # I can delete all the files I won't need going forward
        if ($clean) {
            $log->info("Cleaning up after a workflow step");
            for my $file ($sm->closure->and_not($need)->flags) {
                next unless -e $file;
                my $size = -s $file;
                $log->info("Removing $file, its size is $size");
                system("rm $file") == 0 or $log->warn("Couldn't remove $file");
            }
        }
        $count++;
    }

}

=item steps_done

Return the number of steps of this workflow that are completed.

=cut

sub steps_done {
    my ($self) = @_;
    my $m = $self->state_machine;
    return $m->skippable($m->plan, $self->state);
}

=item is_complete

Return a true value if the current state is a goal state, false
otherwise.

=cut

sub is_complete {
    my ($self) = @_;
    my $goal = $self->state_machine->goal;
    return $self->state->contains($goal);
}

=item missing

Return a list of goal files that are currently missing.

=cut

sub missing {
    my ($self) = @_;
    my $goal = $self->state_machine->goal;
    return $goal->and_not($self->state)->flags;
}

# Given an array ref of filenames, initialize flags for any that I
# don't already know about, and return a bit string representing the
# set of states where all those files exist.
sub _filenames_to_bits {
    my ($self, $files) = @_;
    ref($files) =~ /^ARRAY/ or croak 
        "Filenames must be given as array ref";
    for my $file (@$files) {
        $self->state_machine->flag($file);
    }
    return $self->state_machine->state(@$files);
}


# Given a $path (presumably representing a file that affects my
# state), return a temporary filename based on that path.
sub _temp_filename {
    my ($self, $path) = @_;
    my (undef, $dir, $file) = File::Spec->splitpath($path);
    # TODO: Ensure that files will be different for different runs

    if ($dir && ! -d $dir) {
        mkpath $dir or croak "mkpath $dir: $!";
    }
    my $fh = File::Temp->new(DIR => $dir, TEMPLATE => "$file.tmp.XXXXXXXX", UNLINK => 1);
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
    my $m = $self->state_machine;
    local $_;

    if ($clean_goal) {
      FILE: for my $file ($self->state_machine->flags()) {
            next FILE if ! -e $file;
            $log->debug("veryclean: removing $file");
            eval { unlink $file; };
            if ($@) {
                warn "Couldn't remove $file: $!";
            }
        }        
    }
    else {
        my $state = $self->state;
        my $extra_bits = $state->and_not($m->goal->union($m->start));
        for ($extra_bits->flags) {
            $log->debug("clean: removing $_");
            unlink;
        }
    }
}

1;
