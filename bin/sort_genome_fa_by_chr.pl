#!/usr/bin/perl

=head1 NAME

sort_genome_fa_by_chr.pl

=head1 SYNOPSIS

sort_genome_fa_by_chr.pl F<fasta_file> > out.fa
sort_genome_fa_by_chr.pl < in.fa > out.fa

=head1 DESCRIPTION

Sorts entries in a FASTA file by chromosome.

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
use RUM::Transform qw(:scripts get_options);

get_options();
sort_genome_fa_by_chr;
