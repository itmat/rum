#!/usr/bin/perl

# Written by Gregory R. Grant
# Universiry of Pennsylvania, 2010

if(@ARGV < 1) {
    die "
Usage: create_indexes_from_ucsc.pl <NAME_genome.txt> <NAME_refseq_ucsc>

This script is part of the pipeline of scripts used to create RUM indexes.
For more information see the library file: 'how2setup_genome-indexes_forPipeline.txt'.

Genome fasta file must be formatted as described in:
'how2setup_genome-indexes_forPipeline.txt'.

";
}

$infile = $ARGV[0];
if(!($infile =~ /\.txt$/)) {
    die "ERROR: the <NAME_gnome.txt> file has to end in '.txt', yours doesn't...\n";
}
$F1 = $infile;
$F1 =~ s/.txt$/.fa/;
$F2 = $infile;
$F2 =~ s/.txt$/_one-line-seqs_temp.fa/;
$F3 = $infile;
$F3 =~ s/.txt$/_one-line-seqs.fa/;

print STDERR "perl modify_fasta_header_for_genome_seq_database.pl $infile > $F1\n";
`perl modify_fasta_header_for_genome_seq_database.pl $infile > $F1`;
print STDERR "perl modify_fa_to_have_seq_on_one_line.pl $F1 > $F2\n";
`perl modify_fa_to_have_seq_on_one_line.pl $F1 > $F2`;
print STDERR "perl sort_genome_fa_by_chr.pl $F2 >  $F3\n";
`perl sort_genome_fa_by_chr.pl $F2 >  $F3`;

unlink($F1);
unlink($F2);

$NAME = $ARGV[1];

$N1 = $NAME . "_gene_info_orig.txt";
$N2 = $F3;
$N3 = $NAME . "_genes_unsorted.fa";
$N4 = $NAME . "_gene_info_unsorted.txt";
$N5 = $NAME . "_genes.fa";
$N6 = $NAME . "_gene_info.txt";

print STDERR "perl make_master_file_of_genes.pl gene_info_files > gene_info_merged_unsorted.txt\n";
`perl make_master_file_of_genes.pl gene_info_files > gene_info_merged_unsorted.txt`;
print STDERR "perl fix_geneinfofile_for_neg_introns.pl gene_info_merged_unsorted.txt 5 6 4 > gene_info_merged_unsorted_fixed.txt\n";
`perl fix_geneinfofile_for_neg_introns.pl gene_info_merged_unsorted.txt 5 6 4 > gene_info_merged_unsorted_fixed.txt`;
print STDERR "perl sort_geneinfofile.pl gene_info_merged_unsorted_fixed.txt > gene_info_merged_sorted_fixed.txt\n";
`perl sort_geneinfofile.pl gene_info_merged_unsorted_fixed.txt > gene_info_merged_sorted_fixed.txt`;
print STDERR "perl make_ids_unique4geneinfofile.pl gene_info_merged_sorted_fixed.txt $N1\n";
`perl make_ids_unique4geneinfofile.pl gene_info_merged_sorted_fixed.txt $N1`;
print STDERR "perl get_master_list_of_exons_from_geneinfofile.pl $N1\n";
`perl get_master_list_of_exons_from_geneinfofile.pl $N1`;
print STDERR "perl modify_fa_to_have_seq_on_one_line.pl $N2 > temp.fa\n";
`perl modify_fa_to_have_seq_on_one_line.pl $N2 > temp.fa`;
print STDERR "perl make_fasta_files_for_master_list_of_genes.pl temp.fa master_list_of_exons.txt $N1 $N4 > $N3\n";
print "perl make_fasta_files_for_master_list_of_genes.pl temp.fa master_list_of_exons.txt $N1 $N4 > $N3\n";
`perl make_fasta_files_for_master_list_of_genes.pl temp.fa master_list_of_exons.txt $N1 $N4 > $N3`;
print STDERR "perl sort_gene_info.pl $N4 > $N6\n";
`perl sort_gene_info.pl $N4 > $N6`;
print STDERR "perl sort_gene_fa_by_chr.pl $N3 > $N5\n";
`perl sort_gene_fa_by_chr.pl $N3 > $N5`;

unlink($N3);
unlink($N4);
unlink("temp.fa");

$N6 =~ /^([^_]+)_/;
$organism = $1;

# write rum.config file:
$config = "indexes/$N6\n";
$config = $config . "bin/bowtie\n";
$config = $config . "bin/blat\n";
$config = $config . "bin/mdust\n";
$config = $config . "indexes/$organism" . "_genome\n";
$config = $config . "indexes/$organism" . "_genes\n";
$config = $config . "indexes/$N2\n";
$config = $config . "scripts\n";
$config = $config . "lib\n";
$configfile = "rum.config_" . $organism;
open(OUTFILE, ">$configfile");
print OUTFILE $config;
close(OUTFILE);

unlink("gene_info_merged_unsorted.txt");
unlink("gene_info_merged_unsorted_fixed.txt");
unlink("gene_info_merged_sorted_fixed.txt");
unlink("master_list_of_exons.txt");

# run bowtie on genes index
print STDERR "\nRunning bowtie on the gene index, please wait...\n\n";
$O = $organism . "_genes";
`bowtie-build $N5 $O`;

# run bowtie on genome index
print STDERR "running bowtie on the genome index, please wait this can take some time...\n\n";
$O = $organism . "_genome";
`bowtie-build $F3 $O`;

print STDERR "ok, all done...\n\n";
