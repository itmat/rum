#!perl

use Test::More tests => 6;
use Test::Exception;
use lib "lib";

use strict;
use warnings;
use Log::Log4perl qw(:easy);

BEGIN { 
  use_ok('RUM::Workflow', qw(is_executable_in_path is_dry_run with_settings));
}

ok(is_executable_in_path("perl"), "Executable is in path");
ok(!is_executable_in_path("a-program-that-surely-doesnt-exist-63518313478"), 
   "Executable is not in path");

{
    my $dry_run_val = undef;
    with_settings({dry_run => 1}, sub { $dry_run_val = is_dry_run });
    ok($dry_run_val, "Dry run flag was set");
}


