#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

use lib "lib";
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
use RUM::Config qw(parse_organisms format_config);
use RUM::Task qw(report @QUEUE make_path_rule target action task ftp_rule 
                 satisfy_with_command build chain);
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
my $OUTPUT_DATA_DIR     = "$ROOT/data/Lane1";
my $TEST_INDEX_DIR      = "$ROOT/indexes";
my $RESOURCES_DIR       = "$ROOT/resources";
my $ORGANISMS_FILE      = "$ROOT/organisms.txt";
my $TEST_SCRIPT_DIR     = "orig/scripts";
my $TEST_LIB_DIR        = "orig/lib";

# The test resources git repo gives us a set of input files for Rum,
# some expected output files, and the executables for bowtie, blat,
# and mdust.
my $INPUT_DATA          = "$RESOURCES_DIR/test_mouse/s_1_1.baby";
my $EXPECTED_OUTPUT_DIR = "$RESOURCES_DIR/mouse-expected";
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

# This task makes whatever directories are required for the tests
my $make_paths = task "Make paths",
    target { undef },
    action { },
    [make_path_rule($TEST_INDEX_DIR),
     make_path_rule($EXPECTED_OUTPUT_DIR),
     make_path_rule($OUTPUT_DATA_DIR)];

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
    satisfy_with_command("git", "clone", $TEST_DATA_GIT_SOURCE, $RESOURCES_DIR));


my $compare_output_to_expected = task(
    "Compare Rum output to expected output",
    target { -f "diff.out" },
    action {
        my ($for_real) = @_;
        local $_;
        for my $file (@RUM_OUTPUT_FILES) {
            my $cmd = "diff $EXPECTED_OUTPUT_DIR/$file $OUTPUT_DATA_DIR/$file";
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
    GetOptions(
        "dry-run|n" => \(my $dry_run),
        "verbose|v" => \(my $verbose));
    
    my @targets = @ARGV;

    unless (@targets) {
        die "Usage: $0 [OPTIONS] TARGETS\n";
    }

    for my $name (@targets) {
        my $target = $TARGETS{$name} 
            or die "I don't have a target named $name";
        enqueue $target;
    }

    SKIP : {
        skip "Skipping integration tests", 1 unless $ENV{RUM_INTEGRATION_TESTING};
        build(not($dry_run), $verbose);
    }

}


main();
