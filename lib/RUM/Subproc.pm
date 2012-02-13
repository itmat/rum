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
use warnings;

use POSIX qw(:sys_wait_h);
use Exporter qw(import);
use Carp;

our @EXPORT_OK = qw(spawn check await can_kill procs pids_by_command_re 
                    kill_all child_pids);

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

=item await(PID)

Wait for the given process to finish and return a has with the following keys:

=over 4

=item B<status>

The integer exit status of the process.

=item B<error>

The error message associated with the process, if one exists.

=back

Note that this will block until the other process exits.

=cut


sub await {
    my ($pid) = @_;
    return _wait($pid, 0);
}


=item check(PID)

Check on the status of the given PID and return undef immediately if
the process is still running, otherwise return a hashref like that returned from L<await>.

=cut

sub check {
    my ($pid) = @_;
    return _wait($pid, WNOHANG);
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

Each item in the returned list is a hashref contianing whatever fields
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
    my ($pid, $flags) = @_;
    
    my $got_pid = waitpid($pid, $flags);
    
    if ($got_pid == 0) {
        # carp "Child process $pid is still running";
        return;
    }
    else {
        my $result = { status => $? };
        if ($result->{status}) {
            $result->{error} = $!;
            carp "Child process $pid exited with $?: $!";
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

1;

=back

=head1 AUTHOR

Mike DeLaurentis (delaurentis@gmail.com)

=head1 COPYRIGHT

Copyright 2012 University of Pennsylvania

=cut
