#!/usr/bin/perl

=head1 NAME

make_fasta_file_for_master_list_of_genes.pl

=head1 SYNOPSIS

make_fasta_file_for_master_list_of_genes.pl F<genome-fasta> F<exons> F<gene-info-input-file> F<gene info-output-file> > NAME_genes_unsorted.fa

=head1 DESCRIPTION

This script is part of the pipeline of scripts used to create RUM indexes.
You should probably not be running it alone.  See the library file:
'how2setup_genome-indexes_forPipeline.txt'.

Note: this script will remove from the gene input file anything on a chromosome
for which there is no sequence in the <genome fasta> file.

=head1 OPTIONS

=over 4

=item I<--help|-h>

Get help.

=back

=head1 AUTHOR

Written by Gregory R. Grant, University of Pennsylvania, 2010

=cut

use strict;
use warnings;
use autodie;

use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::Transform qw(transform_file get_options);
use RUM::Transform::GeneInfo qw(make_fasta_files_for_master_list_of_genes);

get_options();
show_usage() unless @ARGV == 4;

with_timing "$0", sub {
  make_fasta_files_for_master_list_of_genes(@ARGV, *STDOUT);
};
