#!/usr/bin/perl

# Written by Gregory R. Grant
# Universiry of Pennsylvania, 2010

use strict;
use warnings;
use autodie;

use FindBin qw($Bin);
use lib ("$Bin/../lib", "$Bin/../lib/perl5");

use RUM::Index;
use RUM::Repository;
use RUM::Script qw(get_options show_usage);
use RUM::Common qw(shell);

use Getopt::Long;
GetOptions("name=s" => \(my $name));

RUM::Script::import_scripts_with_logging();

if(@ARGV < 1) {
    die "
Usage: create_gene_indexes.pl <name> <genome fasta>

This script is part of the pipeline of scripts used to create RUM indexes.
For more information see the library file: 'how2setup_genome-indexes_forPipeline.txt'.

Genome fasta file must be formatted as described in:
'how2setup_genome-indexes_forPipeline.txt'.

";
}

my $N1 = $name . "_gene_info_orig.txt";
my $N2 = $ARGV[0];
my $N3 = $name . "_genes_unsorted.fa";
my $N4 = $name . "_gene_info_unsorted.txt";
my $N5 = $name . "_genes.fa";
my $N6 = $name . "_gene_info.txt";

make_master_file_of_genes("gene_info_files", "gene_info_merged_unsorted.txt");
fix_geneinfofile_for_neg_introns("gene_info_merged_unsorted.txt", "gene_info_merged_unsorted_fixed.txt", 5, 6, 4);
sort_geneinfofile("gene_info_merged_unsorted_fixed.txt", "gene_info_merged_sorted_fixed.txt");
make_ids_unique4geneinfofile("gene_info_merged_sorted_fixed.txt", $N1);
get_master_list_of_exons_from_geneinfofile($N1, "master_list_of_exons.txt");
modify_fa_to_have_seq_on_one_line($N2, "temp.fa");
make_fasta_files_for_master_list_of_genes(["temp.fa", "master_list_of_exons.txt", $N1], [$N4, $N3]);

sort_gene_info($N4, $N6);
sort_gene_fa_by_chr($N3, $N5);
unlink($N3);
unlink($N4);
unlink("temp.fa");
unlink("gene_info_merged_sorted_fixed.txt");
unlink("gene_info_merged_unsorted_fixed.txt");
unlink("gene_info_merged_unsorted.txt");
unlink("master_list_of_exons.txt");
