#!/usr/bin/env perl

use strict;
use warnings;
use FindBin qw($Bin);
use lib ("$Bin/../lib", "$Bin/../lib/perl5");
use RUM::Script;
RUM::Script->run_with_logging("RUM::Script::MergeBowtieAndBlat");

=head1 NAME

merge_Bowtie_and_Blat.pl - Merge results from bowtie and blat

=head1 SYNOPSIS

merge_BowtieUnique_and_BlatUnique.pl --bowtie-unique-in <bowtie_unique_infile> --blat-unique-in <blat_unique_infile> --bowtie-non-unique-in <bowtie_nu_infile> --blat-nu-in <blat_nu_infile> --unique-out <rum_unique_outfile> --non-unique-out <rum_nu_outfile> --single|--paired

=head1 OPTIONS

=over 4

=item B<--bowtie-unique-in> I<bowtie_unique_infile>

The file of unique mappers that is output from the script merge_GU_and_TU.pl.

=item B<--blat-unique-in> I<blat_unique_infile>

The file of unique mappers that is output from the script parse_blat_out.pl.

=item B<--bowtie-non-unique-in> I<bowtie_nu_infile>

The file of non-unique mappers that is output from the script
merge_GNU_and_TNU_and_CNU.pl

=item B<--blat-non-unique-in> I<blat_nu_infile>

The file of non-unique mappers that is output from the script parse_blat_out.pl.

=item B<--unique-out> I<rum_unique_outfile>

The file to write merged unique mappers to.

=item B<--non-unique-out> I<rum_nu_outfile>

The file to write merged non-unique mappers to.

=item B<--paired> | B<--single>

Specify whether the input contains single or paired-end reads.

=item B<--read-length> I<n>

The read length. If not specified I will try to determine it, but if
there aren't enough well-mapped reads I might not get it right. If
there are variable read lengths, set n='v'.

=item B<--min-overlap> I<n>

The minimum overlap required to report the intersection of two
otherwise disagreeing alignments of the same read.

=item B<--max-pair-dist> I<n>

n is an integer greater than zero representing the furthest apart the
forward and reverse reads can be.  They could be separated by an
exon/exon junction so this number can be as large as the largest
intron.  Default value = 500,000.

=item B<-h>, B<--help>

=item B<-v>, B<--verbose>

=item B<-q>, B<--quiet>

=back

=head1 AUTHOR

Gregory Gregory (ggrant@grant.org)

=head1 COPYRIGHT

Copyright 2012 University of Pennsylvania

=cut
