package RUM::Subproc;

use strict;
use warnings;

use POSIX qw(:sys_wait_h);
use Exporter qw(import);
use Carp;

our @EXPORT_OK = qw(spawn check);

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
        carp "Execing @cmd\n";
        exec(@cmd);
        
        # If we make it here, the exec call failed.
        die "Couldn't exec '@cmd': $!";
    }
}

sub check {
    my ($pid) = @_;
    
    my $got_pid = waitpid($pid, WNOHANG);
    
    if ($got_pid == 0) {
        carp "Child process $pid is still running";
        return;
    }
    else {
        my $result = { status => $? };
        $result->{error} = $! if $result->{status};
        carp "Child process $pid exited with $?: $!";
        return $result;
    }
}
