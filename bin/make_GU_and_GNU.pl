#!/usr/bin/env perl

use strict;
use warnings;
use FindBin qw($Bin);
use lib ("$Bin/../lib", "$Bin/../lib/perl5");
use RUM::Script;
RUM::Script->run_with_logging("RUM::Script::MakeGuAndGnu");

=head1 NAME

make_GU_and_GNU.pl

=head1 SYNOPSIS

  make_GU_and_GNU.pl [OPTIONS] --unique <gu_filename> --non-unique <gnu_filename> --single|--paired <bowtie_output>

=head1 DESCRIPTION

=head2 Input

This script takes the output of a bowtie mapping against the genome, which has
been sorted by sort_bowtie.pl, and parses it to have the four columns:

=over 4

=item 1. read name

=item 2. chromosome

=item 3. span

=item 4. sequence

=back

A line of the (input) bowtie file should look like:

  seq.1a   -   chr14   1031657   CACCTAATCATACAAGTTTGGCTAGTGGAAAA

Sequence names are expected to be of the form seq.Na where N in an
integer greater than 0.  The 'a' signifies this is a 'forward' read,
and 'b' signifies 'reverse' reads.  The file may consist of all
forward reads (single-end data), or it may have both forward and
reverse reads (paired-end data).  Even if single-end the sequence
names still must end with an 'a'.

=head2 Output

The line above is modified by the script to be:

  seq.1a   chr14   1031658-1031689   CACCTAATCATACAAGTTTGGCTAGTGGAAAA

In the case of single-end reads, if there is a unique such line for
seq.1a then it is written to the file specified by <gu_filename>.  If
there are multiple lines for seq.1a then they are all written to the
file specified by <gnu_filename>.

In the case of paired-end reads the script tries to match up entries
for seq.1a and seq.1b consistently, which means:

=over 4

=item 1. both reads are on the same chromosome

=item 2. the two reads map in opposite orientations

=item 3. the start of reads are further apart than ends of reads and
no further apart than $max_distance_between_paired_reads

=back

If the two reads do not overlap then the consistent mapper is
represented by two consecutive lines, the forward (a) read first and
the reverse (b) read second.  If the two reads overlap then the two
lines are merged into one line and the a/b designation is removed.

If there is a unique consistent mapper it is written to the file
specified by <gu_filename>.  If there are multiple consistent mappers
they are all written to the file specified by <gnu_filename>.  If only
the forward or reverse read map then it does not write anything.

=cut

=head1 OPTIONS

=over 4

=item B<--unique> I<gu_filename> (required)

The name of the file to be written that will contain unique genome
alignments

=item B<--non-unique> I<gnu_filename> (required)

the name of the file to be written that will contain non-nique genome
alignments

=item B<--single> | B<--paired> (exactly one)

Specify whether the input contains single-end reads or for paired-end
reads.


=item B<--max-pair-dist> I<N>

An integer greater than zero representing the furthest apart the
forward and reverse reads can be.  They could be separated by an
exon/exon junction so this number can be as large as the largest
intron.  Default value = 500,000.

Supply the Bowtie output as the last option on the command line.

=item B<-h>, B<--help>

Get help.

=item B<-q>, B<-quiet>

Be quiet.

=back

=cut

