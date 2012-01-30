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

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib";
use Carp;
use Log::Log4perl qw(:easy);

use RUM::Script qw(get_options show_usage);

Log::Log4perl->easy_init($INFO);

# Parse command line options
get_options("debug" => \(my $debug));
my ($infile, $NAME) = @ARGV;
show_usage unless @ARGV == 2;
die "ERROR: the <NAME_genome.txt> file has to end in '.txt', ".
  "yours doesn't...\n" unless $infile =~ /\.txt$/;

sub unlink_temp_files {
  my @files = @_;
  return if $debug;
  INFO "Removing temporary files @files";
  for my $filename (@files) {
    unlink $filename or warn "Couldn't unlink $filename: $!";
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
      INFO "START $name @args";
      &$long_name(@args);
      INFO "END $name @args";
    };
  }
}
import_scripts_with_logging();

# Put all the filenames we will use in vars.
my $genome_fa = $infile;
my $genome_one_line_seqs_temp = $infile;
my $genome_one_line_seqs = $infile;
$genome_fa =~ s/.txt$/.fa/;
$genome_one_line_seqs_temp =~ s/.txt$/_one-line-seqs_temp.fa/;
$genome_one_line_seqs =~ s/.txt$/_one-line-seqs.fa/;
my $gene_info_orig = $NAME . "_gene_info_orig.txt";
my $genes_unsorted = $NAME . "_genes_unsorted.fa";
my $gene_info_unsorted = $NAME . "_gene_info_unsorted.txt";
my $genes_fa = $NAME . "_genes.fa";
my $gene_info = $NAME . "_gene_info.txt";
my $gene_info_merged_unsorted = "gene_info_merged_unsorted.txt";
my $gene_info_merged_unsorted_fixed = "${gene_info_merged_unsorted}_fixed.txt";
my $gene_info_merged_sorted_fixed = "gene_info_merged_sorted_fixed.txt";
my $gene_info_files = "gene_info_files";
my $master_list_of_exons = "master_list_of_exons.txt";

# Strip extra characters off the headers, join adjacent sequence lines
# together, and sort the genome by chromosome.
modify_fasta_header_for_genome_seq_database($infile, $genome_fa);
modify_fa_to_have_seq_on_one_line($genome_fa, $genome_one_line_seqs_temp);
sort_genome_fa_by_chr($genome_one_line_seqs_temp, $genome_one_line_seqs);
unlink_temp_files($genome_fa, $genome_one_line_seqs_temp);

make_master_file_of_genes($gene_info_files, $gene_info_merged_unsorted);
fix_geneinfofile_for_neg_introns($gene_info_merged_unsorted,
                                 $gene_info_merged_unsorted_fixed,
                                 5, 6, 4);
sort_geneinfofile($gene_info_merged_unsorted_fixed,
                  $gene_info_merged_sorted_fixed);
make_ids_unique4geneinfofile($gene_info_merged_sorted_fixed, $gene_info_orig);
get_master_list_of_exons_from_geneinfofile($gene_info_orig,
                                           $master_list_of_exons);
make_fasta_files_for_master_list_of_genes(
  [$genome_one_line_seqs, $master_list_of_exons, $gene_info_orig],
  [$gene_info_unsorted, $genes_unsorted]);

sort_gene_info($gene_info_unsorted, $gene_info);
sort_gene_fa_by_chr($genes_unsorted, $genes_fa);
unlink_temp_files($genes_unsorted, $gene_info_unsorted, "temp.fa");

$gene_info =~ /^([^_]+)_/;
my $organism = $1;

# write rum.config file:
my $config = "indexes/$gene_info\n";
$config = $config . "bin/bowtie\n";
$config = $config . "bin/blat\n";
$config = $config . "bin/mdust\n";
$config = $config . "indexes/$organism" . "_genome\n";
$config = $config . "indexes/$organism" . "_genes\n";
$config = $config . "indexes/$genome_one_line_seqs\n";
$config = $config . "scripts\n";
$config = $config . "lib\n";
my $configfile = "rum.config_" . $organism;

open my $outfile, ">", $configfile;
print $outfile $config;

unlink_temp_files("gene_info_merged_unsorted.txt",
                  "gene_info_merged_unsorted_fixed.txt",
                  "gene_info_merged_sorted_fixed.txt",
                  "$master_list_of_exons");

sub bowtie {
  my @cmd = ("bowtie-build", @_);
  system(@cmd) == 0 or LOGCROAK "Couldn't run '@cmd': $!";
}

# run bowtie on genes index
INFO "\nRunning bowtie on the gene index, please wait...\n\n";
bowtie($genes_fa, $organism . "_genes");


# run bowtie on genome index
INFO "running bowtie on the genome index, please wait this can take some time...\n\n";
bowtie($genome_one_line_seqs, $organism . "_genome");

INFO "ok, all done...\n\n";

