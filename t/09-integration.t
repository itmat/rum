#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 16 ;

use lib "lib";
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
use RUM::Config qw(parse_organisms format_config);
use RUM::Task qw(report @QUEUE make_path_rule target action task ftp_rule satisfy_with_command build chain);
use Carp;

use Getopt::Long;

GetOptions(
    "dry-run|n" => \(my $dry_run),
    "verbose|v" => \(my $verbose));

our $FOR_REAL = 1;

my $ROOT = "test-data";

# Locations of input files and dirs
my $CONFIG_FILE     = "$ROOT/rum.config_mm9";
my $OUTPUT_DATA_DIR = "$ROOT/data/Lane1";
my $TEST_INDEX_DIR  = "$ROOT/indexes";
my $TEST_BIN_DIR    = "";
my $TEST_SCRIPT_DIR = "orig/scripts";
my $TEST_LIB_DIR    = "orig/lib";
my $ORGANISMS_FILE  = "$ROOT/organisms.txt";

# TODO: Find somewhere to put the input data
my $TEST_DATA_GIT_SOURCE = "/Users/mike/src/rum-integration-tests";
my $TEST_DATA_CHECKOUT_DIR = "$ROOT/input";
my $INPUT_DATA = "$TEST_DATA_CHECKOUT_DIR/test_mouse/s_1_1.baby";

my $EXPECTED_OUTPUT_TARBALL = "expected-output.tgz";
my $EXPECTED_OUTPUT_DIR = "$ROOT/expected";

# These files are produced by Rum
my @RUM_OUTPUT_FILES = qw(PostProcessing-errorlog        
                          junctions_all.rum
                          RUM.sam
                          junctions_high-quality.bed
                          RUM_NU
                          mapping_stats.txt
                          RUM_NU.cov
                          postprocessing_Lane1.log
                          RUM_NU.sorted
                          reads.fa
                          RUM_Unique
                          restart.ids
                          RUM_Unique.cov
                          RUM_Unique.sorted
                          feature_quantifications_Lane1
                          junctions_all.bed
                     );

my @IGNORED_RUM_OUTPUT_FILES = qw(rum.log_chunk.1
                                  rum.error-log
                                  rum.log_master);

my %CONFIG = (
    "gene-annotation-file" => "$TEST_INDEX_DIR/mm9_refseq_ucsc_vega_gene_info.txt",
    "bowtie-bin" => "bowtie",
    "blat-bin"   => "blat",
    "mdust-bin"  => "mdust",
    "bowtie-genome-index" => "$TEST_INDEX_DIR/mm9_genome",
    "bowtie-gene-index" => "$TEST_INDEX_DIR/mm9_genes",
    "blat-genome-index" => "$TEST_INDEX_DIR/mm9_genome_one-line-seqs.fa",
    "script-dir" => $TEST_SCRIPT_DIR,
    "lib-dir" => $TEST_LIB_DIR);

# This task makes whatever directories are required for the tests
my $make_paths = task "Make paths",
    target { undef },
    action { },
    [make_path_rule($TEST_INDEX_DIR),
     make_path_rule($EXPECTED_OUTPUT_DIR)];

# This task downloads the organisms text file to the current directory
my $download_organisims_txt = ftp_rule(
    "http://itmat.rum.s3.amazonaws.com/organisms.txt",
    $ORGANISMS_FILE);

sub get_download_indexes_task {

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
            @organisms = grep {$_->{common} eq 'mouse'} @organisms;
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
        [$make_paths, $download_organisims_txt]);
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

my $download_indexes_task = get_download_indexes_task();

my $get_test_input_data_task = task(
    "Get test input data",
    target { -f $INPUT_DATA },
    satisfy_with_command("git", "clone", $TEST_DATA_GIT_SOURCE, "test-data/input"));

sub all_output_files_exist_in_dir {
    return not grep { not -f "$_[0]/$_" } @RUM_OUTPUT_FILES;
}

my $run_rum_task = task(
    "Rum",
    target { return all_output_files_exist_in_dir($OUTPUT_DATA_DIR) },
    satisfy_with_command("perl", "orig/RUM_runner.pl",
                         $CONFIG_FILE,
                         $INPUT_DATA, $OUTPUT_DATA_DIR, "1", "Lane1"),
    [$download_indexes_task,
     $make_config_file_task,
     $get_test_input_data_task]);

my $untar_expected_output_task = task(
    "Untar expected output data",
    target { all_output_files_exist_in_dir($EXPECTED_OUTPUT_DIR) },
    satisfy_with_command("tar", 
                         "zxvf", $EXPECTED_OUTPUT_TARBALL,
                         "-C", $EXPECTED_OUTPUT_DIR)
);

#Exclude rum.error-log rum.log_chunk.* rum.log_master

my $compare_output_to_expected = task(
    "Compare Rum output to expected output",
    target { -f "diff.out" },
    action {
        local $_;
        for my $file (@RUM_OUTPUT_FILES) {
            my $cmd = "diff $EXPECTED_OUTPUT_DIR/$file $OUTPUT_DATA_DIR/$file";
            open my $pipe, "$cmd |" or croak "Couldn't open $cmd";
            my $diffs = 0;
            while (defined (local $_ = <$pipe>)) {
                $diffs++;
                print;
            }
            is($diffs, 0, "No diffs for $file");
        }
    },
    [$untar_expected_output_task]);

SKIP : {
    skip "Skipping integration tests", 1 unless $ENV{RUM_INTEGRATION_TESTING};
    enqueue $run_rum_task;
    enqueue $compare_output_to_expected;
    build(not($dry_run), $verbose);
}
