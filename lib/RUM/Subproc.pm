package RUM::Subproc;

=head1 NAME

RUM::Subproc - Utilities for dealing with spawned processes

=head2 SYNOPSIS

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

  

=cut

use strict;
use warnings;

use POSIX qw(:sys_wait_h);
use Exporter qw(import);
use Carp;

our @EXPORT_OK = qw(spawn check await can_kill procs pids_by_command_re 
                    kill_all child_pids);

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

sub check {
    my ($pid) = @_;
    return _wait($pid, WNOHANG);
}

sub await {
    my ($pid) = @_;
    return _wait($pid, 0);
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

sub can_kill {
    my ($pid) = @_;
    return int($pid) && kill(0, $pid) == 1;
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

sub procs {
    my %options = @_;
    my @fields = @{ $options{fields} || []};
    my $ps = _open_ps(@fields);
    my @results = _parse_ps($ps);
    close $ps;
    return @results;
}

sub pids_by_command_re {
    my ($re) = @_;
    my @procs = grep { $_->{command} =~ /$re/ } procs(fields => [qw(pid command)]);
    return map { $_->{pid} } @procs;
}

sub kill_all {
    my (@pids) = @_;
    kill(9, @pids);
}

sub child_pids {
    my ($pid) = @_;
    my @procs = procs(fields => [qw(pid ppid)]);
    my @child_procs = grep { $_->{ppid} == $pid } @procs;
    return map { $_->{pid} } @child_procs;
}
