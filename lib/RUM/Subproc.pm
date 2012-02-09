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

sub pids_of_pipeline_shell_scripts {
    my ($outdir, $name, $starttime) = @_;
    my $ps = `ps a | grep $outdir`;
    @candidates = split(/\n/,$ps);
    local $_;
    for (@candidates) {
        if (/^\s*(\d+)\s.*(\s|\/)$outdir\/$name.$starttime.\d+.sh/) {
            push @pids, $1;
        }
    }
}

sub kill_procs {
    my ($outdir, $name, $starttime) = @_;
    my $str = `ps a | grep $outdir`;
    
    my @candidates = split(/\n/,$str);

    for (@candidates) {
        if (/^\s*(\d+)\s.*(\s|\/)$outdir\/$name.$starttime.\d+.sh/) {
            push @pids, $1;
        }
    }
    
    for (@candidates) {    
        if (/^\s*(\d+)\s.*(\s|\/)$outdir(\s|\/)/ && !/pipeline.\d+.sh/) {
            $pid = $1;
            push @pids, $1;
	}
    }

    my $num_killed = kill(9, @pids);
    carp "Only killed $num_killed of ".scalar(@pids)." pids (@pids)"
        unless $num_killed == @pids;

}

sub force_kill {
    my (@pids) = @_;
    while (my $pid = shift()) {
        kill(9, $pid) == 1
            or carp "Couldn't kill $pid: $!";
    }
}
