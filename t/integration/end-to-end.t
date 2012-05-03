#!/usr/bin/env perl

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../../lib";

use File::Path qw(rmtree mkpath);
use File::Temp qw(tempdir);
use Getopt::Long;
use Test::More;


use RUM::TestUtils;
use RUM::Action::Align;

our @READS = map "$SHARED_INPUT_DIR/$_.fq", qw(forward reverse);

GetOptions(
    "no-run" => \(my $NO_RUN),
    "test=s" => \(my $TEST));

if (-e $INDEX_CONFIG) {
    plan tests => 4;
}
else {
    plan skip_all => "Arabidopsis index needed";
}

sub output_dir {
    my ($name) = @_;
    return "$RUM_HOME/t/tmp/end-to-end/$name";
}

sub run_end_to_end {
    my ($name, @addl_args) = @_;
    my $dir = output_dir($name);
    my @args = ("align", "--name", $name, "-o", $dir, 
                "--config", $INDEX_CONFIG, @addl_args);
    my $rum = "$RUM_HOME/bin/rum_runner";

  SKIP: {
        
        skip "--fast supplied, not running rum", 1 if $NO_RUN;
        
        rmtree($dir);
        mkpath($dir);

        system($rum, @args);
        ok(!$?, "Rum exited ok");
    }
}

sub default_files {
    my $name = shift;
    return (
        "RUM.sam",
        "RUM_NU",
        "RUM_NU.cov",
        "RUM_Unique",
        "RUM_Unique.cov",
        "feature_quantifications_$name",
        "inferred_internal_exons.bed",
        "inferred_internal_exons.txt",
        "junctions_all.bed",
        "junctions_all.rum",
        "junctions_high-quality.bed",
        "mapping_stats.txt",
        "novel_inferred_internal_exons_quantifications_$name");
}

sub all_files_exist {
    my ($name, @files) = @_;
    local $_;
    my $dir = output_dir($name);
    for my $file (@files) {
        ok -e "$dir/$file", "$name: $file exists";
    }
}

sub check_defaults {
    run_end_to_end("defaults", @READS);

    my $dir = output_dir("defaults");
    open my $stats, "$dir/mapping_stats.txt";
    my $data = join("", (<$stats>));
    like $data, qr/num_locs\tnum_reads\n1\t577/, "Mapping stats has count by loc";
}

sub check_chunks {
    run_end_to_end("chunks", "--chunks", 3, @READS);
    all_files_exist("chunks", default_files("chunks"));
}

SKIP: {

    check_defaults;
    check_chunks;

}

