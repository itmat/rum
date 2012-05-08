#!/usr/bin/perl

=head1 NAME

get_master_list_of_exons_from_geneinfofile.pl

=head1 SYNOPSIS

get_master_list_of_exons_from_geneinfofile.pl F<gene-info-file> > master_list_of_exons.txt

get_master_list_of_exons_from_geneinfofile.pl < F<gene-info-file> > master_list_of_exons.txt

=head1 DESCRIPTION

This script takes a UCSC gene annotation file and outputs a file of all unique
exons.  The annotation file has to be downloaded with the following fields:

1) chrom
2) strand
3) txStart
4) txEnd
5) exonCount
6) exonStarts
7) exonEnds
8) name

This script is part of the pipeline of scripts used to create RUM indexes.
For more information see the library file: 'how2setup_genome-indexes_forPipeline.txt'.

=head1 OPTIONS

=over 4

=item I<--help|-h>

Get help.

=back

=head1 ARGUMENTS

=over 4

=item F<gene_info_file>

UCSC genee annotation file.

=back

=head1 AUTHOR

Written by Gregory R. Grant, University of Pennsylvania, 2010

=cut

use FindBin qw($Bin);
use lib ("$Bin/../lib", "$Bin/../lib/perl5");
use RUM::Script qw(:scripts get_options show_usage);

get_options();
get_master_list_of_exons_from_geneinfofile;

