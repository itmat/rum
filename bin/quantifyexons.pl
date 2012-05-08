#!/usr/bin/env perl

use strict;
use warnings;
use FindBin qw($Bin);
use lib ("$Bin/../lib", "$Bin/../lib/perl5");
use RUM::Script;
RUM::Script->run_with_logging("RUM::Script::QuantifyExons");

=head1 NAME

quantifyexons.pl

=head1 SYNOPSIS

quantifyexons.pl [OPTIONS] --exons-in <exons_file> --unique-in <rum_unique> --non-unique-in <rum_nu> --output <outfile>

=head1 OPTIONS

=over 4

=item B<--exons-in> I<exons_file>

List of exons in format chr:start-end, one per line.

=item B<--unique-in> I<rum_unique>

The sorted RUM Unique file

=item B<--non-unique-in> I<rum_nu>

The sorted RUM_NU file.

=item B<-o>, B<--output> I<outfile>

The file to write the results to.

=item B<--countsonly>

Output only a simple file with feature names and counts.

=item B<--strand> I<s>

s=p to use just + strand reads, s=m to use just - strand.

=item B<--novel>

Output novel exons only.

=item B<--info> I<f>

A file that maps gene id's to info (i.e. annotation or other gene
ids).  f must be tab delmited with the first column of known ids and
second column of annotation.

=item B<--anti>

Use in conjunction with -strand to record anti-sense transcripts
instead of sense.

=back
