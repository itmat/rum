#!/usr/bin/perl

# Written by Gregory R Grant
# University of Pennsylvania, 2010

use strict;
use warnings;
use FindBin qw($Bin);
use lib ("$Bin/../lib", "$Bin/../lib/perl5");
use RUM::Script;
RUM::Script->run_with_logging("RUM::Script::RumToQuantifications");

=head1 NAME

rum2quantifications.pl

=head1 SYNOPSIS

rum2quantifications.pl [OPTIONS] --genes-in <annot_file> --unique-in
<RUM_Unique> --non-unque-in <RUM_NU> --output <outfile>

=head1 OPTIONS

=over 4

=item B<--genes-in> I<annot_file>

Transcript models file for the RUM pipeline.

=item B<--unique-in> I<rum_unique>

Sorted RUM Unique file.

=item B<--non-unique-in> I<rum_nu>

Sorted RUM NU file.

=item B<-o>, B<--output> I<outfile>

The file to write the results to.

=item B<--sepout> I<filename>

Make separate files for the min and max experssion values.  In this
case will write the min values to <outfile> and the max values to the
file specified by 'filename'.  There are two extra columns in each
file if done this way, one giving the raw count and one giving the
count normalized only by the feature length.

=item B<--posonly>

Output results only for transcripts that have non-zero intensity.
Note: if using -sepout, this will output results to both files for a
transcript if either one of the unique or non-unique counts is zero.

=item B<--countsonly>

Output only a simple file with feature names and counts.

=item B<--strand> I<s>

s=p to use just + strand reads, s=m to use just - strand.

=item B<--info> I<f>

f is a file that maps gene id's to info (i.e. annotation or other gene
ids).  f must be tab delmited with the first column of known ids and
second column of annotation.

=item B<--anti>

Use in conjunction with -strand to record anti-sense transcripts
instead of sense.
