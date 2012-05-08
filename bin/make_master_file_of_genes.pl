#!/usr/bin/perl

=head1 NAME

make_master_file_of_genes.pl

=head1 SYNOPSIS

make_master_file_of_genes F<gene_info_files> > out.fa

=head1 DESCRIPTION

This file takes a set of gene annotation files from UCSC and merges
them into one.  They have to be downloaded with the following fields:

=over 4

=item 1) name

=item 2) chrom

=item 3) strand

=item 4) exonStarts

=item 5) exonEnds

=back

This script is part of the pipeline of scripts used to create RUM indexes.
You should probably not be running it alone.  See the library file:
'how2setup_genome-indexes_forPipeline.txt'.

=head1 OPTIONS

=over 4

=item I<--help|-h>

Get help.

=back

=head1 ARGUMENTS

=over 4

=item F<gene_info_files>

A file that lists the gene info files to operate on.

=back

=head1 AUTHOR

Written by Gregory R. Grant, University of Pennsylvania, 2010

=cut

use FindBin qw($Bin);
use lib ("$Bin/../lib", "$Bin/../lib/perl5");
use RUM::Script qw(:scripts get_options show_usage);

get_options();
show_usage() unless @ARGV == 1;
make_master_file_of_genes, $ARGV[0];
