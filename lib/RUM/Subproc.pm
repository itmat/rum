package RUM::Subproc;

use strict;
use warnings;

use POSIX qw(:sys_wait_h);
use Exporter qw(import);
use Carp;

our @EXPORT_OK = qw(spawn check await);

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
