#!/usr/bin/perl

=head1 NAME

sort_gene_fa_by_chr.pl

=head1 SYNOPSIS

create_indexes_from_ucsc.pl F<NAME_genome.txt> F<NAME>

=head1 DESCRIPTION


=head1 OPTIONS

=over 4

=item I<--help|-h>

Get help.

=item --debug

Run in debug mode. Don't delete intermediate temporary files.

=back

=head1 ARGUMENTS

=over 4

=item F<NAME_genome.txt>

The genome file to operate on.

=item F<NAME>

Name of the genome, used when naming output files.

=back

=head1 AUTHOR

Written by Gregory R. Grant, University of Pennsylvania, 2010

=cut

use FindBin qw($Bin);
use lib "$Bin/../lib";

use RUM::Index qw(run_bowtie);
use RUM::Transform qw(transform_file with_timing get_options);
use RUM::Transform::Fasta qw(:transforms);
use RUM::Transform::GeneInfo qw(:transforms make_fasta_files_for_master_list_of_genes);

use autodie;

my $debug = 0;
get_options("debug" => \$debug);
my ($infile, $NAME) = @ARGV;

if (!($infile =~ /\.txt$/)) {
  die "ERROR: the <NAME_genome.txt> file has to end in '.txt', yours doesn't...\n";
}

sub unlink_temp_files {
  no autodie;
  my $_;
  while (shift) {
    unlink or warn "Couldn't unlink $_: $!";
  }
}

# Strip extra characters off the headers, join adjacent sequence lines
# together, and sort the genome by chromosome.
my $F1 = $infile;
my $F2 = $infile;
my $F3 = $infile;
$F1 =~ s/.txt$/.fa/;
$F2 =~ s/.txt$/_one-line-seqs_temp.fa/;
$F3 =~ s/.txt$/_one-line-seqs.fa/;

transform_file \&modify_fasta_header_for_genome_seq_database, $infile, $F1;
transform_file \&modify_fa_to_have_seq_on_one_line, $F1, $F2;
transform_file \&sort_genome_fa_by_chr, $F2, $F3;

unlink_temp_files($F1, $F2);

$N1 = $NAME . "_gene_info_orig.txt";
$N2 = $F3;
$N3 = $NAME . "_genes_unsorted.fa";
$N4 = $NAME . "_gene_info_unsorted.txt";
$N5 = $NAME . "_genes.fa";
$N6 = $NAME . "_gene_info.txt";

transform_file \&make_master_file_of_genes,
  "gene_info_files", 
  "gene_info_merged_unsorted.txt";

transform_file \&fix_geneinfofile_for_neg_introns, 
  "gene_info_merged_unsorted.txt", 
  "gene_info_merged_unsorted_fixed.txt",
  5, 6, 4;

transform_file \&sort_geneinfofile,
  "gene_info_merged_unsorted_fixed.txt",
  "gene_info_merged_sorted_fixed.txt";

transform_file \&make_ids_unique4geneinfofile,
  "gene_info_merged_sorted_fixed.txt", $N1;

transform_file \&get_master_list_of_exons_from_geneinfofile,
  $N1, "master_list_of_exons.txt";

# TODO: Is this step necessary? I think $N2 already has sequences all on one line
#transform_file \&modify_fa_to_have_seq_on_one_line,
#  $N2, "temp.fa";
system "cp", $N2, "temp.fa";

with_timing "Making fasta files for master list of genes", sub {
  make_fasta_files_for_master_list_of_genes("temp.fa", "master_list_of_exons.txt", $N1, $N4, $N3);
};

transform_file \&sort_gene_info, $N4, $N6;

transform_file \&sort_gene_fa_by_chr, $N3, $N5;



unlink_temp_files($N3, $N4, "temp.fa");
exit;

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

unless ($debug) {
  unlink("gene_info_merged_unsorted.txt");
  unlink("gene_info_merged_unsorted_fixed.txt");
  unlink("gene_info_merged_sorted_fixed.txt");
  unlink("master_list_of_exons.txt");
}

# run bowtie on genes index
print STDERR "\nRunning bowtie on the gene index, please wait...\n\n";
run_bowtie($N5, $organism . "_genes");

# run bowtie on genome index
print STDERR "running bowtie on the genome index, please wait this can take some time...\n\n";
run_bowtie($F3, $organism . "_genome");

print STDERR "ok, all done...\n\n";
