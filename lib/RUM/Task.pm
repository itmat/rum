package RUM::Task;

use strict;
use warnings;
use Carp;

use FindBin qw($Bin);

use Exporter 'import';
use File::Path qw(make_path);
use Log::Log4perl qw(:easy);
our @EXPORT_OK = qw(@QUEUE report make_path_rule target action task ftp_rule satisfy_with_command build chain);

use subs qw(target satisfy task children is_satisfied plan download report);

our @QUEUE;

sub new {
    my ($class, $name, $target, $action, $deps) = @_;
    $deps = [] unless defined $deps;
    croak "First argument of Task must be a name" 
        if ref $name;
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

sub name {
    return $_[0]->{name};
}

sub deps {
    my ($self) = @_;
    my $deps = $self->{deps};
    return @{ $deps } if ref($deps) =~ /ARRAY/;
    return @{ $deps->() };
}

sub queue_deps {
    my ($self) = @_;
    DEBUG "Getting deps for $self->{name}\n";
    return undef if $self->{queued_deps}++;
    if (my @deps = $self->deps) {
        DEBUG "My deps are @deps\n";
        push @QUEUE, $self;
        push @QUEUE, @deps;
        return 1;
    }
    return undef;
}

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

=item shell CMD

Execute cmd with system and croak if it fails.

=cut

sub shell {
    my @cmd = @_;
    system(@cmd) == 0 or croak "Can't execute @cmd: $!";
}


=item task NAME, IS_SATISFIED, ACTION, DEPS

Return a task hash ref.

=over 4

=item NAME

A string that describes the task.

=item IS_SATISFIED

A code ref that takes no arguments and returns true when the task is satisfied.

=item ACTION

A code ref that can be called to satisfy the task. It is called with
one arg; a true value indicates that it should actually do the work,
while a false value indicates that it should only report on what work
it would do (think "make -n").

=item DEPS

An iterator over the dependencies of this task.

=back

=cut

sub task {
    my ($name, $target, $action, $deps) = @_;
    return new RUM::Task($name, $target, $action, $deps);
}


=item is_satisfied TASK

Returns true if the TASK is already satisfied, false otherwise.

=cut

sub is_satisfied {
    return $_[0]->{target}->();
}

=item satisfy_with_command CMD

Returns a sub that when called with a true argument executes CMD, and
when called with a false argument just prints the cmd.

=cut

sub satisfy_with_command {
    my @cmd = @_;
    return sub {
        my ($for_real) = @_;
        if ($for_real) {
            return shell(@cmd);
        }
        else {
            print "@cmd\n";
        }
    }
}

sub download {
    my ($remote, $local) = @_;
    return task(
        "Download $local to $remote",
        target { -f $local },
        satisfy_with_command("scp", $remote, $local));
}

sub copy_file {
    my ($src, $dst, $deps) = @_;
    return task(
        "Copy $src to $dst",
        target { -f $dst },
        satisfy_with_command("cp", $src, $dst),
        $deps);
}

sub build {
    my ($for_real, $verbose) = @_;

    while (@QUEUE) {
        my $task = pop @QUEUE;
        my $name = $task->name;
        DEBUG "Looking at task $name\n";
        if ($task->queue_deps) {
            DEBUG "Queued deps for $name\n";
        }
        
        else {
            DEBUG "Doing work for $name\n";
            my $name = $task->name;
            if (is_satisfied($task)) {
                report "Task '$name' is satisfied" if $verbose;
            }
            else {
                report "Building task '$name'";
                $task->{action}->($for_real);
            }
        }
    }
}

sub enqueue {
    while (my $task = shift()) {
        unshift @QUEUE, $task;
    }
}


sub ftp_rule {
    my ($remote, $local) = @_;
    return task(
        "Download $remote to $local",
        target { -f $local },
        satisfy_with_command("ftp", "-o", $local, $remote));
}

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

sub chain {
    my @subs = @_;
    return sub {
        my @args = @_;
        for my $sub (@subs) {
            $sub->(@args);
        }
    }
}

return 1;
