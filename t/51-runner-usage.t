use Test::More tests => 20;
use Test::Exception;

use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::Repository;
use RUM::TestUtils;
use RUM::Pipeline;
use RUM::Usage;
use File::Path;
use File::Temp qw(tempdir);
use strict;
use warnings;

our $config = "_testing/conf/rum.config_Arabidopsis";

BEGIN { 
    use_ok('RUM::Script::Runner');
}                                               

{
    # Redefine a couple methods in RUM::Usage so we can run the
    # scripts in a way that would normally cause them to exit.

    no warnings "redefine";
   
    *RUM::Usage::bad = sub {
        die "RUM::Usage::bad(@_)";
    };
}

sub run_rum {
    my @args = @_;

    open my $out, ">", \(my $data) or die "Can't open output string: $!";

    *STDOUT_BAK = *STDOUT;
    *STDOUT = $out;

    @ARGV = @args;

    RUM::Script::Runner->main();

    *STDOUT = *STDOUT_BAK;
    close $out;
    return $data;
}

sub version_ok {
    my $version = $RUM::Pipeline::VERSION;
    diag "Trying version";
    like(run_rum("--version"), qr/$version/, "--version prints out version");
    like(run_rum("-V"), qr/$version/, "-V prints out version");
    diag "Tried it";
}

sub help_config_ok {
    my $version = $RUM::Pipeline::VERSION;
    my $out = run_rum("--help-config");
    like($out, qr/gene annotation file/, "--help-config prints config info");
    like($out, qr/bowtie genome index/, "--help-config prints config info");
}

sub check_missing_args {
    warn "Running rum\n";
    throws_ok sub {
        run_rum("--config", $config, "--output", "bar", "--name", "asdf") 
    }, qr/please.*read files/i, "Missing read files";

    throws_ok sub {
        run_rum("--config", $config, "--output", "bar", "--name", "asdf", 
                "1.fq", "2.fq", "3.fq") 
    }, qr/please.*read files/i, "Too many read files";

    throws_ok sub {
        run_rum("--config", $config, "--name", "asdf", "in.fq") 
    }, qr/--output/i, "Missing output dir";

    throws_ok sub {
        run_rum("--config", $config, "--output", "bar", "in.fq") 
    }, qr/--name/i, "Missing name";

    throws_ok sub {
        run_rum("--output", "bar", "--name", "asdf", "in.fq") 
    }, qr/--config/i, "Missing config";

    throws_ok sub {
        run_rum("--config", "missing-config-file",
                "--output", "bar", "--name", "asdf", "in.fq") 
    }, qr/no such file/i, "Config file that doesn't exist";

}

version_ok;
help_config_ok;
check_missing_args;
