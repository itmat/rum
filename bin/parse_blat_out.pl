#!/usr/bin/env perl

use strict;
use warnings;
use FindBin qw($Bin);
use lib ("$Bin/../lib", "$Bin/../lib/perl5");
use RUM::Script;
RUM::Script->run_with_logging("RUM::Script::ParseBlatOut");

=head1 NAME

parse_blat_out.pl

=head1 SYNOPSIS

  parse_blat_out.pl --reads-in  <seq_file> --blat-in <blat_file> --mdust-in <mdust_file> --unique-out <blat_unique_outfile> --non-unique-out <blat_nu_outfile> [options]

=head1 OPTIONS

=over 4

=item B<--reads-in> I<seq_file>

The fasta file of reads output from make_unmapped_file.pl.

=item B<--blat-in> I<blat_file>

The file output from blat being run on F<seq_file>.

=item B<--mdust-in> I<mdust_file>

The file output from mdust being run on F<seq_file>.

=item B<--unique-out> I<blat_unique_outfile>

The file to write unique blat mappers to.

=item B<--non-unique-out> I<blat_nu_outfile>

The file to write non-unique blat mappers to.

=item B<--max-pair-dist> I<N>

N is an integer greater than zero representing the furthest apart the
forward and reverse reads can be.  They could be separated by an
exon/exon junction so this number can be as large as the largest
intron.  Default value = 500,000

=item B<--dna>

Set this flag if aligning DNA sequence data.

=item B<--match-length-cutoff> I<N>

Set this min length alignment to be reported

=item B<--max-insertions> I<n>

Allow n insertions in one read.  The default is n=1.  Setting n>1 only
allowed for single end reads.  Don't raise it unless you know what you
are doing, because it can greatly increase the false alignments.

=item B<-h>, B<--help>

=item B<-v>, B<--verbose>

=item B<-q>, B<--quiet>

I<Note:> All three files should preferrably be in order by sequence
number, and if paired end the a's come before the b's.  The blat file
will be checked for this and fixed if not, the other two are not
checked, so make sure they conform.

=back

=head1 AUTHOR

Gregory Gregory (ggrant@grant.org)

=head1 COPYRIGHT

Copyright 2012 University of Pennsylvania

=cut
