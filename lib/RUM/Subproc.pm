package RUM::Subproc;

=head1 NAME

RUM::Subproc - Utilities for dealing with spawned processes

=head1 SYNOPSIS

  use RUM::Subproc qw(spawn check await can_kill procs pids_by_command_re
                      kill_all child_pids);

  # Spawn a new process and get its pid
  my $child_pid = spawn("ls -l");

  # Check on the status of a running process, returning undef
  # immediately if it's still running, or a hash with "status" and
  # "error" keys if it failed.
  my $status = check($child_pid);
  if ($status) {
    if ($status->{status} == 0) {
      print "Child finished ok\n";
    }
    else {
      print "Child exited with status $child->{status}: $child->{error}\n";
    }
  }
  else {
    print "Child is still running\n";
  }
  
  # Wait for the child process to finish. Works exactly like check,
  # but blocks until the child exits (so it never returns undef to
  # indicate that it's still running.
  my $status = await($child_pid);

  # Find out whether a process is running and I have control over it
  can_kill($pid);

  # Get a list of processes from ps, including specified fields:
  my @procs = procs(qw("pid", "ppid", "command"))

  # Get a list of pids whose command matches a regex
  my @pids = pids_by_command_re(qr/RUM_runnner.pl/);

  # Get a list of child pids for a parent pid
  my @child_pid = child_pids($pid);

  # Kill a list of pids
  kill_all(@child_pids);

=head1 DESCRIPTION

Provides utilities for dealing with child processes. These functions
use system calls such as fork, exec, and kill where possible, and
shell out to other processes when we need to.

=head2 Subroutines

=over 4

=cut

use strict;
no warnings;

use POSIX qw(:sys_wait_h);
use Exporter qw(import);
use Carp;
use File::Spec;

our @EXPORT_OK = qw(spawn check await can_kill procs pids_by_command_re 
                    kill_all child_pids kill_runaway_procs);

# Maps a pid to the command that we used to spawn the process. spawn
# puts values in this map, and _wait removes them.
our %COMMANDS;

=item spawn(CMD)

Spawns another processes running the given CMD and returns the pid of
the new process immediately. CMD can be a string or array, similar to
I<system>.

=cut

sub spawn {
    my @cmd = @_;
    
    # Fork creates a child process and returns the pid of the new
    # process to the parent process.
    if (my $pid = fork()) {
        $COMMANDS{$pid} = [@cmd];
        return $pid;
    }
    
    # The child process starts executing right at the fork command, but
    # we can tell it's the child because fork doesn't return the pid to
    # the child.
    else {
        # carp "Execing @cmd\n";
        exec(@cmd);
    }
}

=item await(PID, OPTIONS)

Wait for the given process to finish and return a hash. OPTIONS can have the following keys:

=over 4

=item B<quiet>

Don't complain when a child process exits with a non-zero status.

=back

The hash returned will have the following keys:

=over 4

=item B<status>

The integer exit status of the process.

=item B<error>

The error message associated with the process, if one exists.

=back

Note that this will block until the other process exits.

=cut


sub await {
    my ($pid, %options) = @_;
    return _wait($pid, 0, %options);
}


=item check(PID)

Check on the status of the given PID and return undef immediately if
the process is still running, otherwise return a hashref like that returned from L<await>.

=cut

sub check {
    my ($pid, %options) = @_;
    return _wait($pid, WNOHANG, %options);
}


=item can_kill(PID)

Return true of PID is running and I have the ability to signal it;
return false otherwise.

=cut

sub can_kill {
    my ($pid) = @_;
    return int($pid) && kill(0, $pid) == 1;
}

=item procs(OPTIONS)

Return a list of processes, using the "ps" command.

OPTIONS can have the following keys:

=over 4

=item B<fields>

List of string field names. See the man page for ps for allowable fields.

=back

Each item in the returned list is a hashref containing whatever fields
were requested in the "fields" option.

=cut

sub procs {
    my %options = @_;
    my @fields = @{ $options{fields} || []};
    my $ps = _open_ps(@fields);
    my @results = _parse_ps($ps);
    close $ps;
    return @results;
}

=item pids_by_command_re(RE)

Return a list of all the pids whose command matches the given regular
expression, using the "ps" command.

=cut

sub pids_by_command_re {
    my ($re) = @_;
    my @procs = grep { $_->{command} =~ /$re/ } procs(fields => [qw(pid command)]);
    return map { $_->{pid} } @procs;
}

=item kill_all(PIDS)

Send the 9 (KILL) signal to the pids in the given list. Returns the
number of processes that were successfully signaled.

=cut

sub kill_all {
    my (@pids) = @_;
    kill(9, @pids);
}

=item child_pids(PID)

Return a list of pids that are children of the given pid, using the
"ps" command.

=cut

sub child_pids {
    my ($pid) = @_;
    my @procs = procs(fields => [qw(pid ppid)]);
    my @child_procs = grep { $_->{ppid} == $pid } @procs;
    return map { $_->{pid} } @child_procs;
}


sub _wait {
    my ($pid, $flags, %options) = @_;
    
    my $got_pid = waitpid($pid, $flags);
    
    if ($got_pid == 0) {
        # carp "Child process $pid is still running";
        return;
    }
    else {
        my $result = { status => $? };
        my @cmd = @{ delete($COMMANDS{$pid}) || [] };
        if ($result->{status}) {
            $result->{error} = $!;
            carp "Child process $pid (@cmd) exited with $?: $!" 
                unless $options{quiet};
        }
        return $result;
    }
}


sub _parse_ps {
    my ($ps) = @_;

    my $header_line = <$ps>;
    
    $header_line =~ s/^\s+|\s+$//g;
#    print "Header line is now '$header_line'\n";
    my @headers = split /\s+/, $header_line;
#    print "Headers are ", join("|", @headers);
    my @res;
    while (defined(my $line = <$ps>)) {
        $line =~ s/^\s+|\s+$//g;
        my @row = split /\s+/, $line, scalar(@headers);
        my %rec;
        for my $i (0 .. $#headers) {
            $rec{lc($headers[$i])} = $row[$i];
        }
        push @res, \%rec;
    }
    return @res;
}

sub _open_ps {
    my (@fields) = @_;
    my $fields = join(",", @fields);
    my $cmd = "ps a -o $fields |";
    open my $ps, $cmd or croak "Couldn't open $cmd: $!";
    return $ps;
}

=item kill_runaway_procs(OUTDIR, OPTIONS)

Kill any "runaway" processes, whose command contains OUTDIR. We expect
that any such processes are RUM-related. First we kill any scripts
that look like <outdir>/<name>.<starttime>.<chunk>.sh. We kill them
first because because those scripts kick off other scripts, and we
want to stop these scripts from launching more programs
immediately. Then we kill any other programs whose command contains my
output directory.

OPTIONS can contain the following keys:

=over 4

=item B<name>

The name of the job to look for in the
<outdir>/<name>.<starttime>.<chunk>.sh; if you leave this blank I'll
kill jobs with any name.

=item B<starttime>

The start time of the job to kill. If you leave it blank I'll kill
jobs with any start time.

=item B<chunk>

The chunk number to kill. If you leave it blank I'll kill
jobs with any chunk number.

=back

B<TODO>: I'm not sure if it even makes sense to have the above
options. I think we end up killing all processes that have the output
directory in the command anyway. Eventually we should explicitly keep
track of the PIDs of all the processes that we spawn so we know
exactly which processes to kill.

=cut

sub kill_runaway_procs {
    my ($outdir, %options) = @_;

    my $name      = delete $options{name}      || qr/\w+/;
    my $starttime = delete $options{starttime} || qr/\d+/;
    my $chunk     = delete $options{chunk}     || qr/\d+/;

    if (my @unrecognized = keys %options) {
        croak "Unrecognized options for kill_runaway_procs: @unrecognized";
    }

    # Make sure the caller didn't give us an empty path or a path that
    # specifies something other than a directory, so we don't kill too
    # many processes.
    -d $outdir 
        or croak "outdir must specify a directory: $outdir";
    File::Spec->splitdir($outdir) > 0 
        or croak("outdir must not be an empty path: $outdir");

    my $kill_first_re = qr/\b$outdir\/$name\.$starttime\.$chunk\.sh\b/;
    my $kill_later_re = qr/\b$outdir\b/;

    #carp "Looking for processes to kill.";
    #carp "Will kill these first: $kill_first_re";
    #carp "Then kill these: $kill_later_re";

    # Collect a list of processes that we want to kill.
    my @kill;
    for my $proc (procs(fields => [qw(pid command)])) {
        local $_ = $proc->{command};

        if ($proc->{pid} == $$) {
            # Don't kill myself.
        }

        elsif (/$kill_first_re/) {
            # Scripts that look like this are used to launch other
            # scripts, so we should kill this one before the other
            # ones. Unshift it onto the front of the kill list.
            unshift @kill, $proc;
        }

        elsif (/pipeline.$chunk.sh/) {
            # Don't kill it. TODO: Not sure why; this is how
            # RUM_runner.pl was behaving.
        }

        elsif (/$kill_later_re/) {
            # Any other scripts that are running in this directory should
            # be killed at the end.
            push @kill, $proc;
        }
    }

    # Now kill all the processes and set the 'killed' key in each
    # process's hash, so the caller can see which ones we were able to
    # kill.
    for my $proc (@kill) {
        carp "Killing $proc->{pid} ($proc->{command})";
        $proc->{killed} = kill 9, $proc->{pid} or carp(
            "Couldn't kill process with pid $proc->{pid} ".
                "and command '$proc->{command}': $!");
    }
    return @kill;
}

=back

=head1 AUTHOR

Mike DeLaurentis (delaurentis@gmail.com)

=head1 COPYRIGHT

Copyright 2012 University of Pennsylvania

=cut

1;


