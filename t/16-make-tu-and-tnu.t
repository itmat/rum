#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 4;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::Script::MakeTuAndTnu;
use RUM::TestUtils qw(no_diffs);
use File::Temp;

my $in = "$Bin/data/Y.1";
my $tempdir = "$Bin/tmp";
my $expected_dir = "$Bin/expected/make_tu_and_tnu";
my $gene_info = "$Bin/../_testing/indexes/Arabidopsis_thaliana_TAIR10_ensembl_gene_info.txt";

sub temp_filename {
    my ($template) = @_;
    File::Temp->new(
        DIR => "$Bin/tmp",
        UNLINK => 0,
        TEMPLATE => $template);
}

sub paired_ok {
    my $u  = temp_filename("transcriptome-paired-unique.XXXXXX");
    my $nu = temp_filename("transcriptome-paired-non-unique.XXXXXX");
    @ARGV = ("--bowtie", $in,
             "--genes", $gene_info,
             "--unique", $u, 
             "--non-unique", $nu, 
             "--paired", "-q");

    RUM::Script::MakeTuAndTnu->main();
    no_diffs($u,  "$expected_dir/transcriptome-paired-unique",
             "paired unique");
    no_diffs($nu, "$expected_dir/transcriptome-paired-non-unique",
             "paired non-unique");
}

sub single_ok {
    my $u  = temp_filename("transcriptome-single-unique.XXXXXX");
    my $nu = temp_filename("transcriptome-single-non-unique.XXXXXX");
    @ARGV = ("--bowtie", $in,
             "--genes", $gene_info,
             "--unique", $u, 
             "--non-unique", $nu, 
             "--single", "-q");
    RUM::Script::MakeTuAndTnu->main();
    no_diffs($u,  "$expected_dir/transcriptome-single-unique",
             "single unique");
    no_diffs($nu, "$expected_dir/transcriptome-single-non-unique",
             "single non-unique");
}

SKIP: {
    skip "Don't have arabidopsis index", 4 unless -e $gene_info;
    paired_ok();
    single_ok();
}

