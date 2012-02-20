#!/usr/bin/perl

# Written by Gregory R. Grant
# Universiry of Pennsylvania, 2010

if(@ARGV < 1) {
    die "
Usage: create_gene_indexes.pl <name> <genome fasta>

This script is part of the pipeline of scripts used to create RUM indexes.
For more information see the library file: 'how2setup_genome-indexes_forPipeline.txt'.

Genome fasta file must be formatted as described in:
'how2setup_genome-indexes_forPipeline.txt'.

";
}

$NAME = $ARGV[0];

$N1 = $NAME . "_gene_info_orig.txt";
$N2 = $ARGV[1];
$N3 = $NAME . "_genes_unsorted.fa";
$N4 = $NAME . "_gene_info_unsorted.txt";
$N5 = $NAME . "_genes.fa";
$N6 = $NAME . "_gene_info.txt";

`perl make_master_file_of_genes.pl gene_info_files > gene_info_merged_unsorted.txt`;
`perl fix_geneinfofile_for_neg_introns.pl gene_info_merged_unsorted.txt 5 6 4 > gene_info_merged_unsorted_fixed.txt`;
`perl sort_geneinfofile.pl gene_info_merged_unsorted_fixed.txt > gene_info_merged_sorted_fixed.txt`;
`perl make_ids_unique4geneinfofile.pl gene_info_merged_sorted_fixed.txt $N1;`;
`perl get_master_list_of_exons_from_geneinfofile.pl $N1`;
`perl modify_fa_to_have_seq_on_one_line.pl $N2 > temp.fa`;
`perl make_fasta_files_for_master_list_of_genes.pl temp.fa master_list_of_exons.txt $N1 $N4 > $N3`;
`perl sort_gene_info.pl $N4 > $N6`;
`perl sort_gene_fa_by_chr.pl $N3 > $N5`;
unlink($N3);
unlink($N4);
unlink("temp.fa");

$config = "indexes/$N6\n";
$N6 =~ /^([^_]+)_/;
$organism = $1;
$config = $config . "bin/bowtie\n";
$config = $config . "bin/blat\n";
$config = $config . "bin/mdust\n";
$config = $config . "indexes/$organism" . "_genome\n";
$config = $config . "indexes/$organism" . "_genes\n";
$config = $config . "indexes/$organism" . "_genome_one-line-seqs.fa\n";
$config = $config . "scripts\n";
$config = $config . "lib\n";

$configfile = "rum.config_" . $organism;
open(OUTFILE, ">$configfile");
print OUTFILE $config;
close(OUTFILE);
