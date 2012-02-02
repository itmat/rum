package RUM::Task;

=head1 NAME

RUM::Task - Task and dependency framework

=head1 DESCRIPTION

=head2 Subroutines

=over 4

=cut

use strict;
use warnings;
use Carp;

use FindBin qw($Bin);

use Exporter 'import';
use File::Path qw(make_path rmtree);
use Log::Log4perl qw(:easy);

our @EXPORT_OK = qw(@QUEUE report make_path_rule target action task ftp_rule 
                    satisfy_with_command build chain enqueue rule);

use subs qw(action target satisfy task children is_satisfied plan
            download report);

our @QUEUE;

=item RUM::Task->new(NAME, TARGET, ACTION, DEPS)

=cut

sub new {
    my ($class, $name, $target, $action, $deps) = @_;
    $deps = [] unless defined $deps;
#    croak "First argument of Task must be a name" 
#        if ref($name) ;
    croak "Second argument of Task must be a targetition test" 
        unless ref($target) =~ /CODE/;
    croak "Third argument of Task must be a precondition" 
        unless ref($action) =~ /CODE/;
    croak "Fourth arg must be code or an array ref" 
        unless (ref($deps) =~ /CODE/ or ref($deps) =~ /ARRAY/);
    
    return bless {
        name => $name,
        target => $target,
        action => $action,
        deps => $deps }, $class;
}



=item task NAME, TARGET, ACTION, DEPS

Return a task object.

=over 4

=item NAME

A string that describes the task.

=item TARGET

A code ref that takes no arguments and returns true when the task is
satisfied.

=item ACTION

A code ref that can be called to satisfy the task. It is called with
one arg; a true value indicates that it should actually do the work,
while a false value indicates that it should only report on what work
it would do (think "make -n").

=item DEPS

Either an ref to an array of tasks that must be run before this task
can be run, or a code ref that will return such a list when called.

=back

=cut

sub task {
    my ($name, $target, $action, $deps) = @_;
    return new RUM::Task($name, $target, $action, $deps);
}

sub rule {
    my (@args) = @_;
    croak "Odd number of options to rule" unless @args % 2 == 0;
    my (%options) = @_;
    return task($options{name} || "",
                $options{target} || sub { undef },
                $options{action} || sub { },
                $options{depends_on} || [ ]);
}

=back

=head3 RUM::Task methods

=over 4

=item $task->name()

Return the name of the task.

=cut

sub name {
    my ($self, $options, @args) = @_;;
    my $name = $self->{name};
    if (ref($name) =~ /CODE/) {
        return $name->($options, @args);
    }
    return $name;
}

=item $task->deps(OPTIONS, ARGS)

Return a list of the tasks that must be run before this task can be
run.

=cut

sub deps {
    my ($self, $options, @args) = @_;
    my $deps = $self->{deps};
    return @{ $deps } if ref($deps) =~ /ARRAY/;
    return @{ $deps->($options, @args) };
}

=item $task->queue_deps()

Add the dependencies of this task to the @QUEUE.

=cut

sub queue_deps {
    my ($self, $options, @args) = @_;
    DEBUG "Getting deps for $self->{name}\n";
    return undef if $self->{queued_deps}++;
    if (my @deps = $self->deps($options, @args)) {
        DEBUG "My deps are @deps\n";
        push @QUEUE, $self;
        push @QUEUE, @deps;
        return 1;
    }
    return undef;
}

=item $task->is_satisfied()

Returns true if the TASK is already satisfied, false otherwise.

=cut

sub is_satisfied {
    my ($self, $options, @args) = @_;
    return $self->{target}->($options, @args);
}

=item report ARGS

Print ARGS as a message prefixed with a "#" character.

=cut

sub report {
    my @args = @_;
    print "# @args\n";
}

=item target CODE

Marker for a sub that should return true when the task is considered
satisfied and false otherwise.

=cut

sub target (&) {
    return $_[0];
}

=item action CODE

Marker for a sub that should be called to satisfy a task, assuming all
of its dependencies are satisfied.

=cut

sub action (&) {
    return $_[0];
}





=back

=head3 Canned actions

Each of these subs return an anonymous sub that can be used as an
action in a call to task().

=over 4

=cut

=item satisfy_with_command CMD

Returns a sub that when called with a true argument executes CMD, and
when called with a false argument just prints the cmd.

=cut

sub satisfy_with_command {
    my @cmd = @_;
    return sub {
        my ($options) = @_;
        if ($options->{dry_run}) {
            print "@cmd\n";
        }
        else {
            system(@cmd) == 0 or croak "Can't execute @cmd: $!";
        }
    }
}


=item chain ACTIONS

Chain together some actions: return an action that when executed
simply executes all of the given ACTIONs in order.

=cut

sub chain {
    my @actions = @_;
    return sub {
        my @args = @_;
        for my $action (@actions) {
            $action->(@args);
        }
    }
}

=back

=head3 Canned Tasks

=over 4

=item ftp_rule REMOTE, LOCAL

A task that does nothing if LOCAL exists, otherwise downloads a file
identified by REMOTE and saves it to LOCAL.

=cut

sub ftp_rule {
    my ($remote, $local) = @_;
    return task(
        "Download $remote to $local",
        target { -f $local },
        satisfy_with_command("ftp", "-o", $local, $remote));
}

=item copy_file SOURCE, DEST

A task that does nothing if LOCAL exists, otherwise copies a file
identified by SOURCE and saves it to DEST.

=cut

sub copy_file {
    my ($src, $dst, $deps) = @_;
    return task(
        "Copy $src to $dst",
        target { -f $dst },
        satisfy_with_command("cp", $src, $dst),
        $deps);
}


=item make_path_rule PATH

A task that creates a path on the filesystem if it doesn't already exist.

=cut

sub make_path_rule {
    my ($path) = @_;
    return task(
        "Make path $path",
        target { -d $path },
        action { 
            if ($_[0]) {
                make_path($path);
            }
            else {
                print "mkdir -p $path\n";
            }
        });
}

=item rmtree_task PATH

A task that removes an entire directory tree if it exists. I<USE WITH
CAUTION!!!>

=cut

sub rmtree_task {
    my ($path) = @_;
    return task(
        "Remove $path",
        target { not -d $path },
        action { 
            my ($options) = @_;
            if ($options->{dry_run}) {
                print "rm -rf $path";
            }
            else {
                rmtree($path);
            }
        });
}

=item build FOR_REAL, VERBOSE

Build any tasks currently in the @QUEUE. If FOR_REAL is a true value,
actually run the tasks; otherwise just print out some diagnostic
information. If VERBOSE is true, print out extra information.

=cut

sub build {
    my ($options, @args) = @_;

    while (@QUEUE) {
        my $task = pop @QUEUE;
        my $name = $task->name($options, @args);
        DEBUG "Looking at task $name\n";
        if ($task->queue_deps($options, @args)) {
            DEBUG "Queued deps for $name\n";
        }
        
        else {
            DEBUG "Doing work for $name\n";
            my $name = $task->name($options, @args);
            if ($task->is_satisfied($options, @args)) {
                report "Task '$name' is satisfied" if $options->{verbose};
            }
            else {
                report "Building task '$name'";
                $task->{action}->($options, @args);
            }
        }
    }
}

=item enqueue TASKS

Add all the given TASKS to the queue in order.

=cut

sub enqueue {
    while (my $task = shift()) {
        unshift @QUEUE, $task;
    }
}


return 1;

