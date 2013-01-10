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
our @FASTA = map "$SHARED_INPUT_DIR/$_.fa", qw(forward reverse);
our @FASTA_VAR = map "$SHARED_INPUT_DIR/$_.var.fa", qw(forward reverse);
our @FASTQ_VAR = map "$SHARED_INPUT_DIR/$_.var.fq", qw(forward reverse);

GetOptions(
    "no-run" => \(my $NO_RUN),
    "test=s" => \(my $TEST));

if (-e $INDEX_CONFIG) {
    plan tests => 303;
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
                "--index", $INDEX_DIR, @addl_args);
    my $rum = "$RUM_HOME/bin/rum_runner";

  SKIP: {
        
        skip "--fast supplied, not running rum", 1 if $NO_RUN;
        
        rmtree($dir);
        mkpath($dir);

        diag "Running \"$rum @args\"";
        system($rum, @args);
        ok(!$?, "Rum exited ok");
    }
}

sub default_files {
    my $name = shift;
    return (
        "reads.fa",
        "quals.fa",
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

sub no_files_exist {
    my ($name, @files) = @_;
    local $_;
    my $dir = output_dir($name);
    for my $file (@files) {
        ok ! -e "$dir/$file", "$name: $file does not exist";
    }
}

################################################################################
###
### Defaults: two fastq files, no extra options
###

sub check_defaults {
    my $name = "defaults";
    run_end_to_end($name, '--chunks', 1, @READS);
    all_files_exist($name, default_files($name));
    my $dir = output_dir("defaults");
    open my $stats, "$dir/mapping_stats.txt";
    my $data = join("", (<$stats>));
    like $data, qr/num_locs\tnum_reads\n1\t569/, "Mapping stats has count by loc";
}

################################################################################
###
### Varying command-line options
###

sub check_chunks {
    run_end_to_end("chunks", "--chunks", 3, @READS);
    all_files_exist("chunks", default_files("chunks"));
}

sub check_strand_specific {
    my $name = "strand-specific";
    run_end_to_end($name, '--chunks', 1, "--strand-specific", @READS);

    my @files = default_files($name);
    push @files, ("RUM_NU.plus.cov",
                  "RUM_NU.plus",
                  "RUM_Unique.plus.cov",
                  "RUM_Unique.plus",
                  "RUM_NU.minus.cov",
                  "RUM_NU.minus",
                  "RUM_Unique.minus.cov",
                  "RUM_Unique.minus",
              );

    all_files_exist($name, @files);
}

sub check_alt_quants {
    my $name = "alt-quants";
    run_end_to_end($name, '--chunks', 1, "--alt-quant", $GENE_INFO, @READS);
    all_files_exist($name,
                    default_files($name),
                    "feature_quantifications_$name.altquant");
}

sub check_strand_specific_alt_quants {
    my $name = "strand-specific-alt-quants";

    run_end_to_end(
        $name, 
        '--chunks', 1,
        "--strand-specific", "--alt-quant", $GENE_INFO, @READS);

    my @files = default_files($name);
    push @files, ("RUM_NU.plus.cov",
                  "RUM_NU.plus",
                  "RUM_Unique.plus.cov",
                  "RUM_Unique.plus",
                  "RUM_NU.minus.cov",
                  "RUM_NU.minus",
                  "RUM_Unique.minus.cov",
                  "RUM_Unique.minus",
              );

    push @files, "feature_quantifications_$name.altquant";
    all_files_exist($name, @files);
}

sub check_dna {
    my $name = "dna";
    run_end_to_end($name, '--chunks', 1, "--dna", @READS);

    my $rule = qr/quant|exons|junctions/;

    my @files = default_files($name);
    my @kept    = grep { !/$rule/ } @files;
    my @removed = grep {  /$rule/ } @files;

    all_files_exist($name, @kept);
    no_files_exist($name, @removed);
}


sub check_dna_quant {
    my $name = "dna-quant";
    run_end_to_end($name, '--chunks', 1, "--dna", "--quant", @READS);

    my $rule = qr/exons|junctions/;

    my @files = default_files($name);
    my @kept    = grep { !/$rule/ } @files;
    my @removed = grep {  /$rule/ } @files;

    all_files_exist($name, @kept);
    no_files_exist($name, @removed);
}

sub check_dna_junctions {
    my $name = "dna-junctions";
    run_end_to_end($name, '--chunks', 1, "--dna", "--junctions", @READS);

    my $rule = qr/quant/;

    my @files = default_files($name);
    my @kept    = grep { !/$rule/ } @files;
    my @removed = grep {  /$rule/ } @files;

    all_files_exist($name, @kept);
    no_files_exist($name, @removed);
}

sub check_dna_junctions_quant {
    my $name = "dna-junctions-quant";
    run_end_to_end($name, '--chunks', 1, "--dna", "--junctions", "--quant", @READS);
    all_files_exist($name, default_files($name));
}


sub check_genome_only {
    my $name = "genome-only";
    run_end_to_end($name, '--chunks', 1, "--genome-only", @READS);

    my $rule = qr/quant/;

    my @files = default_files($name);
    my @kept    = grep { !/$rule/ } @files;
    my @removed = grep {  /$rule/ } @files;

    all_files_exist($name, @kept);
    no_files_exist($name, @removed);
}

sub check_blat_only {
    my $name = "blat-only";
    run_end_to_end($name, '--chunks', 1, @READS);
    all_files_exist($name, default_files($name));
}

################################################################################
###
### Varying input types
###

sub check_one_fastq {
    my $name = "one-fastq";
    run_end_to_end($name, '--chunks', 1, $READS[0]);
    all_files_exist($name, default_files($name));
}

sub check_two_fasta {
    my $name = "two-fasta";
    run_end_to_end($name, '--chunks', 1, @FASTA);
    my @files = grep { not /quals.fa/ } default_files($name);
    all_files_exist($name, @files);
}

sub check_one_fasta {
    my $name = "one-fasta";
    run_end_to_end($name, '--chunks', 1, $FASTA[0]);
    my @files = grep { not /quals.fa/ } default_files($name);
    all_files_exist($name, @files);
}


sub check_one_fasta_var_length {
    my $name = "one-fasta-var-length";
    run_end_to_end($name, '--chunks', 1, $FASTA_VAR[0]);
    my @files = grep { not /quals.fa/ } default_files($name);
    all_files_exist($name, @files);
}

sub check_two_fasta_var_length {
    my $name = "one-fasta-var-length";
    run_end_to_end($name, '--chunks', 1, @FASTA_VAR);
    my @files = grep { not /quals.fa/ } default_files($name);
    all_files_exist($name, @files);
}

sub check_one_fastq_var_length {
    my $name = "one-fastq-var-length";
    run_end_to_end($name, '--chunks', 1, $FASTQ_VAR[0]);
    all_files_exist($name, default_files($name));
}

sub check_two_fastq_var_length {
    my $name = "one-fastq-var-length";
    run_end_to_end($name, '--chunks', 1, @FASTQ_VAR);
    all_files_exist($name, default_files($name));
}



SKIP: {
   check_defaults;
    check_chunks;
    check_strand_specific; 
    check_alt_quants;
    check_strand_specific_alt_quants;
    check_dna;
    check_dna_quant;
    check_dna_junctions;
    check_dna_junctions_quant;
    check_genome_only;
    check_blat_only;
    check_one_fastq;
    check_two_fasta;
    check_one_fasta;
   check_one_fasta_var_length;
    check_two_fasta_var_length;
    check_one_fastq_var_length;
    check_two_fastq_var_length;
}

