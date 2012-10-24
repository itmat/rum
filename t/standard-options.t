#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::TestUtils;
use RUM::Usage;
use RUM::Logging;
use File::Find;

our $LAST_HELPED = "";

{
    # Redefine a couple methods in RUM::Usage so we can run the
    # scripts in a way that would normally cause them to exit.

    # If we call a script with --help or -h, it should call
    # RUM::Usage->help, which calls pod2usage, which causes the script
    # to exit (not with die, but with exit()). We don't want it to
    # exit, we just want to record the fact that help() was called for
    # that script.

    no warnings "redefine";
   
    *RUM::Usage::help = sub {
        ($LAST_HELPED) = caller();
        if ($LAST_HELPED eq 'RUM::Script::Base') {
            ($LAST_HELPED) = caller(4);
        }
    };

    # After RUM::Usage::help is called, the script will probably call
    # RUM::Usage->bad since we're not providing any parameters that
    # the script actually needs. We'll redefine that method so that it
    # dies, and then look for the die message as part of the test.
    
    *RUM::Usage::bad = sub {
        die "RUM::Usage::bad was called";
    };
}

my @libs;

find sub {
    /^(\w*)\.pm$/ or return;
    # Skip Main. We know it doesn't support --verbose, --quiet, or
    # --help, because it delegates to other classes for command-line
    # parsing.
    return if m{Main.pm};
    return if m{Base.pm};
    push @libs, ["RUM/Script/$_", "RUM::Script::$1"];
}, "$Bin/../lib/RUM/Script";

plan tests => scalar(@libs) * 3;

sub run_main {
    my ($package, @args) = @_;

    @ARGV = @args;

    # Temporarily redirect STDERR to a string, so the die message
    # doesn't get printed to my test output.
    my $stderr_data = "";
    open my $stderr, ">", \$stderr_data;
    *STDERR_BAK = *STDERR;
    *STDERR = $stderr;

    eval { $package->main() };

    *STDERR = *STDERR_BAK;
}

for my $lib (@libs) {

    my ($file, $package) = @{ $lib };

    require_ok $file;
    run_main($package, "-h");
#    is($LAST_HELPED, $package, "Got help for $package");

    if ($@ && $@ !~ /RUM::Usage::bad was called/) {
#        fail("Error calling help on $package: $@");
    }
    else {
#        pass("Called help on $package");
    }

    # Now run the script with the -v and -q options and make sure that
    # the script responds by adjusting the log level. 
    
    # First capture the "baseline" logging level (whatever the level
    # was without the -q or -v option).
    my $log = RUM::Logging->get_logger($package);
    my $baseline_level = $log->level;

    # Then run it verbosely and capture the threshold.
    run_main($package, "-h", "--verbose");
    my $verbose_level = $log->level;

    # Then run it quietly and capture the threshold.
    run_main($package, "--quiet", "-h");
    my $quiet_level = $log->level;

    ok($verbose_level < $baseline_level, "$package: --verbose");
    ok($quiet_level > $verbose_level,    "$package: --quiet");
}
