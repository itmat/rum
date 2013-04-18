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

=item --debug|d

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

BEGIN{
    
use FindBin qw($Bin);
use lib ("$Bin/../lib", "$Bin/../lib/perl5");
    use RUM::Logging;
    RUM::Logging->init('.');
}

use strict;
use autodie;
use warnings;

use Carp;
use File::Spec;

use FindBin qw($Bin);
use lib ("$Bin/../lib", "$Bin/../lib/perl5");

use RUM::Index;
use RUM::Repository;
use RUM::Script qw(get_options show_usage);

my $log = RUM::Logging->get_logger;
my $ui = RUM::Logging->get_logger('RUM::UI');


# Parse command line options
get_options("debug" => \(my $debug));
my ($infile, $NAME) = @ARGV;
show_usage unless @ARGV == 2;

sub unlink_temp_files {
  my @files = @_;
  return if $debug;
  $log->info("Removing temporary files @files");
  for my $filename (@files) {
#    unlink $filename;
  }
}

sub import_scripts_with_logging {
  my @names = @{$RUM::Script::EXPORT_TAGS{scripts}};
  for my $name (@names) {
    no strict "refs";
    my $long_name = "RUM::Script::$name";
    my $new_name  = "main::$name";
    *{$new_name} = sub {
      my @args = @_;
      $ui->info("START $name @args");
      &$long_name(@args);
      $ui->info("END $name @args");
    };
  }
}
import_scripts_with_logging();

sub warn_if_empty {
    while (my $filename = shift) {
        if ( ! -s $filename ) {
            $ui->warn("$filename is empty, this is a bad sign");
        }
    }
}

my @parts = split /_/, $NAME;
my $organism = $parts[0];
mkdir $organism unless -d $organism;

my $gene_info = "$organism/${NAME}_gene_info.txt";

# Put all the filenames we will use in vars.

my $genome_base = $infile =~ /^(.*).txt/ && $1 or die(
    "Genome file must end with .txt");

my $genome_txt = "$genome_base.txt";
my $genome_fa = "${genome_base}.fa";
my $genome_one_line_seqs_temp = "${genome_base}_one-line-seqs_temp.fa";
my $genome_one_line_seqs = "$organism/${genome_base}_one-line-seqs.fa";
my $gene_info_orig = $NAME . "_gene_info_orig.txt";
my $genes_unsorted = $NAME . "_genes_unsorted.fa";
my $gene_info_unsorted = $NAME . "_gene_info_unsorted.txt";
my $genes_fa = $NAME . "_genes.fa";
my $gene_info_merged_unsorted = "gene_info_merged_unsorted.txt";
my $gene_info_merged_unsorted_fixed = "gene_info_merged_unsorted_fixed.txt";
my $gene_info_merged_sorted_fixed = "gene_info_merged_sorted_fixed.txt";
my $gene_info_files = "gene_info_files";
my $master_list_of_exons = "master_list_of_exons.txt";

# Strip extra characters off the headers, join adjacent sequence lines
# together, and sort the genome by chromosome.

 modify_fasta_header_for_genome_seq_database($genome_txt, $genome_fa);

modify_fa_to_have_seq_on_one_line($genome_fa, $genome_one_line_seqs_temp);
warn_if_empty($genome_one_line_seqs_temp);

sort_genome_fa_by_chr($genome_one_line_seqs_temp, $genome_one_line_seqs);
warn_if_empty($genome_one_line_seqs);

unlink_temp_files($genome_one_line_seqs_temp);

make_master_file_of_genes($gene_info_files, $gene_info_merged_unsorted);
warn_if_empty($gene_info_merged_unsorted);

fix_geneinfofile_for_neg_introns($gene_info_merged_unsorted,
                                 $gene_info_merged_unsorted_fixed,
                                 5, 6, 4);
warn_if_empty($gene_info_merged_unsorted_fixed);

sort_geneinfofile($gene_info_merged_unsorted_fixed,
                  $gene_info_merged_sorted_fixed);
warn_if_empty($gene_info_merged_sorted_fixed);

make_ids_unique4geneinfofile($gene_info_merged_sorted_fixed, $gene_info_orig);
warn_if_empty($gene_info_orig);

get_master_list_of_exons_from_geneinfofile($gene_info_orig,
                                           $master_list_of_exons);
warn_if_empty($master_list_of_exons);

make_fasta_files_for_master_list_of_genes(
  [$genome_one_line_seqs, $master_list_of_exons, $gene_info_orig],
  [$gene_info_unsorted, $genes_unsorted]);
warn_if_empty($gene_info_unsorted,
              $genes_unsorted);

sort_gene_info($gene_info_unsorted, $gene_info);
warn_if_empty($gene_info);

sort_gene_fa_by_chr($genes_unsorted, $genes_fa);
warn_if_empty($genes_fa);

unlink_temp_files($genes_unsorted, $gene_info_unsorted);

sub basename {
    my ($filename) = @_;
    my @parts = File::Spec->splitpath($filename);
    return $parts[$#parts];
}

my $genome_size = RUM::Repository::genome_size($genome_one_line_seqs);

# write rum.config file:
my $config = RUM::Index->new(
    gene_annotations           => basename($gene_info),
    bowtie_genome_index        => basename("${organism}_genome"),
    bowtie_transcriptome_index => basename("${NAME}_genes"),
    genome_fasta               => basename($genome_one_line_seqs),
    genome_size                => $genome_size,
    directory                  => $organism);

$config->save;

unlink_temp_files("gene_info_merged_unsorted.txt",
                  "gene_info_merged_unsorted_fixed.txt",
                  "gene_info_merged_sorted_fixed.txt",
                  "$master_list_of_exons");

sub bowtie {
  my @cmd = ("bowtie-build", @_);
  system(@cmd) == 0 or die "Couldn't run '@cmd': $!";
}

my $no_genes;

# run bowtie on genes index
warn "\nRunning bowtie on the gene index, please wait...\n\n";
if (-s $genes_fa) {
    bowtie($genes_fa, "$organism/${NAME}_genes");
}
else {
    $no_genes = 1;
}

# run bowtie on genome index
warn "running bowtie on the genome index, please wait this can take some time...\n\n";
bowtie($genome_one_line_seqs, "$organism/${organism}_genome");

if ($no_genes) {
    warn("The $genes_fa file is empty, which means this will be a genome-only index, with no gene annotations. If this is not what you intended, then something has gone wrong.\n");
}
warn "ok, all done...\n\n";

