#!/usr/bin/env perl

use strict;
use warnings;
use FindBin qw($Bin);
use lib ("$Bin/../lib", "$Bin/../lib/perl5");
use RUM::Script;
RUM::Script->run_with_logging("RUM::Script::MergeGuAndTu");

=head1 NAME

merge_GU_and_TU.pl

=head1 SYNOPSIS


merge_GU_and_TU.pl --gu-in <gu_in> --tu-in <tu_in> --gnu-in <gnu_in> --tnu-in <tnu_in> --bowtie-unique-out <bowtie_unique_out> --cnu-out <cnu_out> --single|--paired

=head1 OPTIONS

=over 4

=item B<--gu-in> I<gu_infile>

The file of unique mappers that is output from the script
make_GU_and_GNU.pl

=item B<--tu-in> I<tu_infile>

The file of unique mappers that is output from the script
make_TU_and_TNU.pl

=item B<--gnu-in> I<gnu_infile> 

The file of non-unique mappers that is output from the script
make_GU_and_GNU.pl

=item B<--tnu-in> I<tnu_infile>

The file of non-unique mappers that is output from the script
make_TU_and_TNU.pl

=item B<--bowtie-unique-out> I<bowtie_unique_outfile>

The name of the file of unique mappers to be output

=item B<--cnu-out> I<cnu_outfile>

The name of the file of non-unique mappers to be output

=item B<--single> | B<--paired>

Specify whether the input contains single-end reads or for paired-end
reads.

=item B<--read-length> I<n>

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
