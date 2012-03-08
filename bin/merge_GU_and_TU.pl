#!/usr/bin/env perl

use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::Script;
RUM::Script->run_with_logging("RUM::Script::MergeGuAndTu");

=head1 NAME

merge_GU_and_TU.pl

=head1 SYNOPSIS


merge_GU_and_TU.pl <GU infile> <TU infile> <GNU infile> <TNU infile> <BowtieUnique outfile> <CNU outfile> <type>

=head1 OPTIONS

=over 4

=item B<--gu> I<gu_infile>

The file of unique mappers that is output from the script
make_GU_and_GNU.pl

=item B<--tu> I<tu_infile>

The file of unique mappers that is output from the script
make_TU_and_TNU.pl

=item B<--gnu> I<gnu_infile> 

The file of non-unique mappers that is output from the script
make_GU_and_GNU.pl

=item B<--tnu> I<tnu_infile>

The file of non-unique mappers that is output from the script
make_TU_and_TNU.pl

=item B<--bowtie-unique <bowtie_unique_outfile>

The name of the file of unique mappers to be output

=item B<--cnu> I<cnu_outfile>

The name of the file of non-unique mappers to be output

=item B<--single> | B<--paired>

Specify whether the input contains single-end reads or for paired-end
reads.

=item B<--readlength> I<n>

The read length, if not specified I will try to determine it, but if
there aren't enough well mapped reads I might not get it right.  If
there are variable read lengths, set n=v.

=item B<--min-overlap> I<n>

The minimum overlap required to report the intersection of two
otherwise disagreeing alignments of the same read.

=item B<--max-pair-dist> I<N>

An integer greater than zero representing the furthest apart the
forward and reverse reads can be.  They could be separated by an
exon/exon junction so this number can be as large as the largest
intron.  Default value = 500,000.

=cut
