#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

use lib "lib";
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
use RUM::Config qw(parse_organisms format_config);
use RUM::Task qw(report @QUEUE make_path_rule target action task ftp_rule 
                 satisfy_with_command build chain enqueue);
use Carp;

use Getopt::Long;

################################################################################
###
### Config
###

my $ROOT = "_testing";

# TODO: Find somewhere to put the input data
my $TEST_DATA_GIT_SOURCE    = "/Users/mike/src/rum-integration-tests";

# Locations of input files and dirs
my $CONFIG_FILE         = "$ROOT/rum.config_mm9";
my $TEST_INDEX_DIR      = "$ROOT/indexes";
my $RESOURCES_DIR       = "$ROOT/resources";
my $ORGANISMS_FILE      = "$ROOT/organisms.txt";
my $TEST_SCRIPT_DIR     = "orig/scripts";
my $TEST_LIB_DIR        = "orig/lib";

# The test resources git repo gives us a set of input files for Rum,
# some expected output files, and the executables for bowtie, blat,
# and mdust.
my $INPUT_DATA          = "$RESOURCES_DIR/test_mouse/s_1_1.baby";
my $BIN_DIR             = "$RESOURCES_DIR/bin-$^O";

# These files are produced by Rum
my @RUM_OUTPUT_FILES = qw(PostProcessing-errorlog        
                          junctions_all.rum
                          RUM.sam
                          junctions_high-quality.bed
                          RUM_NU
                          mapping_stats.txt
                          RUM_NU.cov
                          RUM_NU.sorted
                          reads.fa
                          RUM_Unique
                          restart.ids
                          RUM_Unique.cov
                          RUM_Unique.sorted
                          feature_quantifications_Lane1
                          junctions_all.bed
                     );

sub expected_output_dir {
    my ($test_name) = @_;
    return "$RESOURCES_DIR/${test_name}-expected";
}

sub output_data_dir {
    my ($test_name) = @_;
    return "$ROOT/data/$test_name/Lane1";
}

# Rum produces these files too, but we don't compare them to the
# expected output because they're too variable.
my @IGNORED_RUM_OUTPUT_FILES = qw(rum.log_chunk.1
                                  rum.error-log
                                  postprocessing_Lane1.log
                                  rum.log_master);


my %CONFIG = (
    "bowtie-bin" => "$BIN_DIR/bowtie",
    "blat-bin"   => "$BIN_DIR/blat",
    "mdust-bin"  => "$BIN_DIR/mdust",
    "gene-annotation-file" => "$TEST_INDEX_DIR/mm9_refseq_ucsc_vega_gene_info.txt",
    "bowtie-genome-index"  => "$TEST_INDEX_DIR/mm9_genome",
    "bowtie-gene-index"    => "$TEST_INDEX_DIR/mm9_genes",
    "blat-genome-index"    => "$TEST_INDEX_DIR/mm9_genome_one-line-seqs.fa",
    "script-dir" => $TEST_SCRIPT_DIR,
    "lib-dir" => $TEST_LIB_DIR);

sub make_paths_task {
    my ($run_name) = @_;
    # This task makes whatever directories are required for the tests
    return task(
        "Make paths",
        target { undef },
        action { },
        [make_path_rule(expected_output_dir($run_name)),
         make_path_rule(output_data_dir($run_name))]);
}

my $make_paths = make_paths_task("mouse");

# This task downloads the organisms text file to the current directory
my $download_organisims_txt = ftp_rule(
    "http://itmat.rum.s3.amazonaws.com/organisms.txt",
    $ORGANISMS_FILE);

sub download_indexes_task {
    my ($build_name) = @_;
    my @organisms;

    my $download_indexes = task(
        "Download indexes",
        target { undef },
        action {
            report "Parsing organisms file";
            open my $orgs, "<", $ORGANISMS_FILE;
            @organisms = parse_organisms($orgs) 
                or croak "I can't parse the organisms file";
            
            # Filter the organisms to include only mouse
            @organisms = grep {$_->{build} eq $build_name} @organisms;

            # Get all the URLs listed for any orgs we're interested in
            my @urls = map { @{ $_->{files} } } @organisms;

            # For each of the URLs, enqueue a task that will download it
            for my $url (@urls) {
                my $file = $TEST_INDEX_DIR . "/" .
                    substr($url, rindex($url, "/") + 1);
                if ($file =~ /^(.*)\.gz$/) {
                    my $unzipped = $1;
                    push @QUEUE, task(
                        "Download and unzip $file",
                        target { -f $unzipped },
                        chain(
                            satisfy_with_command("ftp", "-o", $file, $url),
                            satisfy_with_command("gunzip", $file)));
                    }
                else {
                    push @QUEUE, ftp_rule($url, $file);
                }
            }
        },
        [make_path_rule($TEST_INDEX_DIR),
         $download_organisims_txt]);
    return $download_indexes;
}

# This task ensures that the config file is created
my $make_config_file_task = task(
    "Make config file",
    target { -f $CONFIG_FILE },
    action {
        open my $out, ">", $CONFIG_FILE;
        print $out format_config(%CONFIG);
    },
    [$make_paths]);

my $download_indexes_task = download_indexes_task("mm9");

my $get_test_input_data_task = task(
    "Get test input data",
    target { -f $INPUT_DATA },
    satisfy_with_command("git", "clone", $TEST_DATA_GIT_SOURCE, $RESOURCES_DIR));

sub all_output_files_exist_in_dir {
    return not grep { not -f "$_[0]/$_" } @RUM_OUTPUT_FILES;
}

my $run_rum_task = task(
    "Rum",
    target { return all_output_files_exist_in_dir(output_data_dir("mouse")) },
    satisfy_with_command("perl", "orig/RUM_runner.pl",
                         $CONFIG_FILE,
                         $INPUT_DATA, output_data_dir("mouse"), "1", "Lane1"),
    [$download_indexes_task,
     $make_config_file_task,
     $get_test_input_data_task]);

my $untar_expected_output_task = task(
    "Untar expected output data",
    target { all_output_files_exist_in_dir(expected_output_dir("mouse")) },
    satisfy_with_command("git", "clone", $TEST_DATA_GIT_SOURCE, $RESOURCES_DIR));


sub diff_cmd {
    my ($test_name, $file) = @_;
    my $expected_dir = expected_output_dir($test_name);
    my $output_dir   = output_data_dir($test_name);
    return "diff $expected_dir/$file $output_dir/$file";
}

my $compare_output_to_expected = task(
    "Compare Rum output to expected output",
    target { -f "diff.out" },
    action {
        my ($for_real) = @_;
        local $_;
        for my $file (@RUM_OUTPUT_FILES) {
            my $cmd = diff_cmd("mouse", $file);
            if ($for_real) {
                open my $pipe, "$cmd |" or croak "Couldn't open $cmd";
                my $diffs = 0;
                while (defined (local $_ = <$pipe>)) {
                    $diffs++;
                    print;
                }
                is($diffs, 0, "No diffs for $file");
            }
            else {
                print "$cmd\n";
            }
        }
    },
    [$untar_expected_output_task,
     $run_rum_task]);

our %TARGETS = (
    "mouse-test" => $compare_output_to_expected
);

sub main {

    if ($ENV{RUM_INTEGRATION_TESTING}) {
        enqueue($TARGETS{"mouse-test"});
        build(1);
        return;
    }
    else {
        skip "Not running integration tests", 1;
    }
    


    GetOptions(
        "dry-run|n" => \(my $dry_run),
        "verbose|v" => \(my $verbose));

    my @targets = @ARGV;

    unless (@targets) {
        print "Usage: $0 [OPTIONS] TARGETS\n";
        done_testing();
        return;
    }

    for my $name (@targets) {
        my $target = $TARGETS{$name} 
            or die "I don't have a target named $name";
        enqueue $target;
        build;
    }

}


main();
