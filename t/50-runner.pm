use Test::More tests => 20;
use Test::Exception;

use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::Repository;
use RUM::TestUtils;
use RUM::Pipeline;
use File::Path;
use File::Temp qw(tempdir);
use strict;
use warnings;

BEGIN { 
    use_ok('RUM::Script::Runner');
}                                               

our $ARABIDOPSIS_CONFIG = "$Bin/../_testing/conf/rum.config_Arabidopsis";

my $repo = RUM::Repository->new(root_dir => "$Bin/../_testing");

our $OUT_DIR = "t/tmp/50-runner";
mkdir $OUT_DIR;
sub check_single_reads_file_ok {
    {
        my $config = RUM::Config->new(reads => ["$SHARED_INPUT_DIR/reads.fa"]);
        my $runner = RUM::Script::Runner->new(config => $config);

        $runner->check_single_reads_file;
        ok($config->paired_end, "Is paired end");
        ok($config->input_needs_splitting, "Needs splitting");
        ok($config->input_is_preformatted, "Preformatted");
    }
    {
        my $config = RUM::Config->new(reads => ["$SHARED_INPUT_DIR/forward_only.fa"]);
        my $runner = RUM::Script::Runner->new(config => $config);
        
        $runner->{reads} = ["$SHARED_INPUT_DIR/forward_only.fa"];
        $runner->check_single_reads_file;
        
        ok( ! $config->paired_end, "Is paired end");
        ok($config->input_needs_splitting, "Needs splitting");
        ok($config->input_is_preformatted, "Preformatted");
    }
}

sub check_double_reads_ok {
    {
        my $config = RUM::Config->new(
            output_dir => $OUT_DIR,
            reads => ["$SHARED_INPUT_DIR/forward.fq",
                      "$SHARED_INPUT_DIR/reverse.fq"]);
        my $runner = RUM::Script::Runner->new(config => $config);
        $runner->check_read_file_pair;
    }
}

sub reformat_reads_ok {
    my $config = RUM::ChunkConfig->new(
        config_file => $ARABIDOPSIS_CONFIG,
        output_dir => $OUT_DIR,
        bin_dir => "$Bin/../bin");
    my $runner = RUM::Script::Runner->new(
        config => $config);

    $runner->{reads} = ["$SHARED_INPUT_DIR/forward.fq",
                        "$SHARED_INPUT_DIR/reverse.fq"];

    $runner->setup;
    $runner->reformat_reads();
    $runner->check_read_length();
    $runner->run_chunks();
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
    like(run_rum("--version"), qr/$version/, "--version prints out version");
    like(run_rum("-V"), qr/$version/, "-V prints out version");
}

sub help_config_ok {
    my $version = $RUM::Pipeline::VERSION;
    my $out = run_rum("--help-config");
    like($out, qr/gene annotation file/, "--help-config prints config info");
    like($out, qr/bowtie genome index/, "--help-config prints config info");
}

#check_single_reads_file_ok();
#check_double_reads_ok();
#reformat_reads_ok();
version_ok();
help_config_ok;
