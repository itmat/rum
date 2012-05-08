#!/usr/bin/perl

=head1 NAME

modify_fasta_header_for_genome_seq_database

=head1 SYNOPSIS

modify_fasta_header_for_genome_seq_database.pl F<fasta_file> > out.fa
modify_fasta_header_for_genome_seq_database.pl < in.fa > out.fa

=head1 DESCRIPTION

This expects a fasta file with header that looks like:

  >hg19_ct_UserTrack_3545_+ range=chrUn_gl000248:1-39786 ...

and it modifies it to look like this:

  >chrUn_gl000248

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

=item F<fasta_file>

File to operate on.

=back

=head1 AUTHOR

Written by Gregory R. Grant, University of Pennsylvania, 2010

=cut

use FindBin qw($Bin);
use lib ("$Bin/../lib", "$Bin/../lib/perl5");
use RUM::Script qw(:scripts get_options);

get_options();
modify_fasta_header_for_genome_seq_database;
