#!perl

use Test::More tests => 13;
use lib "lib";

use strict;
use warnings;

BEGIN { 
  use_ok('RUM::Subproc', qw(spawn check await can_kill procs pids_by_command_re 
                            child_pids kill_all));
}

{
    my $pid = spawn("sleep 0.5");
    ok($pid > 0, "spawn a child process");
    ok(can_kill($pid), "I should be able to kill the process");
    ok(!defined(check($pid)), "shouldn't have an exit status yet");
    kill_all($pid);
    is(await($pid, quiet=>1)->{status}, 9, "wait for a child process");
}

# Parse the output of ps
{
    my @procs = procs(fields => [qw(pid command)]);
    ok(@procs > 1, "procs found some processes");
    is((grep{keys(%$_) == 2} @procs), @procs, "All procs have 2 keys");
    is((grep{$_->{command}} @procs), @procs, "All procs have a command");
    is((grep{$_->{pid}} @procs), @procs, "All procs have a pid");
}

{
    my @pids = pids_by_command_re(qr/perl/);
    ok(@pids > 0, "Found a Perl process");
    ok(not (grep{ not int($_) } @pids), "All pids were ints");
}

{
    my $child = spawn("sleep 10");
    my @children = child_pids($$);
    ok(grep($_ == $child, child_pids($$)), "child_pids found my child");
    kill_all($child);
    await($child, quiet=>1);
    ok(grep($_ == $child, child_pids($$)) == 0,
       "child_pids did not find my child");
}
