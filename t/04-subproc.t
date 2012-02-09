#!perl

use Test::More tests => 3;
use Test::Exception;
use lib "lib";

use strict;
use warnings;
use Log::Log4perl qw(:easy);

BEGIN { 
  use_ok('RUM::Subproc', qw(spawn check await));
}

{
    my $pid = spawn("sleep 0.5");
    ok($pid > 0, "spawn a child process");
    ok(!defined(check($pid)), "process should still be running now");
    is(await($pid)->{status}, 0, "wait for a child process");
}

