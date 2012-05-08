#!/usr/bin/env perl

use strict;
use warnings;
use FindBin qw($Bin);
use lib ("$Bin/../lib", "$Bin/../lib/perl5");
use RUM::Script;
RUM::Script->run_with_logging("RUM::Script::MakeTuAndTnu");

=head1 NAME

make_TU_and_TNU.pl - Create unique and non-unique mappers from bowtie output

=head1 SYNOPSIS

make_TU_and_TNU.pl [OPTIONS] --bowtie-output <bowtie_file> --genes <gene_annot_file> --unique <tu_filename> --non-unique <tnu_filename> --single|--paired

=head1 DESCRIPTION

=head2 Input

This script takes the output of a bowtie mapping against the
transcriptome, which has been sorted by sort_bowtie.pl, and parses it
to have the four columns:

=over 4

=item 1. read name

=item 2. chromosome

=item 3. span

=item 4. sequence

=back

A line of the (input) bowtie file should look like:

  seq.167a   -   GENE_1321     411    AGATATGATTCACGAAGAGTTAACCCTGATGG

Sequence names are expected to be of the form seq.Na where N in an
integer greater than 0.  The 'a' signifies this is a 'forward' read,
and 'b' signifies 'reverse' reads.  The file may consist of all
forward reads (single-end data), or it may have both forward and
reverse reads (paired-end data).  Even if single-end the sequence
names still must end with an 'a'.


=head2 Output

The line above is modified by the script to:

  seq.167a   chr14    122572-122588, 122701-122715    AGATATGATTCACGAAG:AGTTAACCCTGATGG

The colon indicates the location of the splice junction.

In the case of single-end reads, if there is a unique such line for
seq.1a then it is written to the file specified by <tu_filename>.  If
there are multiple lines for seq.1a then they are all written to the
file specified by <tnu_filename>.

In the case of paired-end reads the script tries to match up entries for seq.1a and seq.1b consistently, which means:

=over 4

=item 1. both reads are on the same chromosome

=item 2. the two reads map in opposite orientations

=item 3. the start of reads are further apart than ends of reads and
no further apart than $max_distance_between_paired_reads

=back

If the two reads do not overlap then the consistent mapper is
represented by two consecutive lines, each with the same sequence name
except the forward ends with 'a' and the reverse ends with 'b'.  In
the case that the two reads overlap then they two lines are merged
into one line and the a/b designation is removed.

If there is a unique set of consistent mappers it is written to the file specified by <tu_filename>.  If there are multiple consistent mappers they are all written to the file specified by <tnu_filename>.  If only the forward or reverse read map then it does not write anything.

=head1 OPTIONS

=over 4

=item B<--bowtie-output> I<bowtie file>

The file outptu from bowtie.

=item B<--genes> I<gene annot file>

The file of gene models.

=item B<--unique> I<tu filename>

The name of the file to be written that will contain unique
transcriptome alignments.

=item B<--non-unique> I<tnu filename>

The name of the file to be written that will contain non-unique
transcriptome alignments.

=item B<--single> | B<--paired>

Specify whether the input contains single-end reads or for paired-end
reads.

=item B<--max-pair-dist> I<N>

An integer greater than zero representing the furthest apart the
forward and reverse reads can be.  They could be separated by an
exon/exon junction so this number can be as large as the largest
intron.  Default value = 500,000.

=item B<-h>, B<--help>

Get help.

=item B<-q>, B<-quiet>

Be quiet.

=back

=head1 AUTHOR

Gregory Grant (ggrant@grant.org)

=head1 COPYRIGHT

Copyright 2012 University of Pennsylvania

=cut
