#!/usr/bin/env perl

# Written by Gregory R Grant
# University of Pennsylvania, 2010

use strict;
use warnings;
use FindBin qw($Bin);
use lib ("$Bin/../lib", "$Bin/../lib/perl5");
use RUM::Script;
RUM::Script->run_with_logging("RUM::Script::CountReadsMapped");

=head1 NAME

count_reads_mapped.pl

=head1 SYNOPSIS

count_reads_mapped.pl [OPTIONS] --unique-in <rum_unique_file> --non-unique-in <rum_nu_file>

=head1 DESCRIPTION

File lines should look like this:
seq.6b  chr19   44086924-44086960, 44088066-44088143    CGTCCAATCACACGATCAAGTTCTTCATGAACTTTGG:CTTGCACCTCTGGATGCTTGACAAGGAGCAGAAGCCCGAATCTCAGGGTGGTGCTGGTTGTCTCTGTGACTGCCGTAA

=head1 OPTIONS

=over 4

=item B<--unique-in> I<rum_unique_file>

=item B<--non-unique-in> I<rum_nu_file>

The sorted RUM_Unique and RUM_NU files, respectively.

=item B<--max-seq> I<n>

Specify the max sequence id, otherwise will just use the max seq id found in the two files.

=item B<--min-seq> I<n>

Specify the min sequence id, otherwise will just use the min seq id found in the two files.

=back

=cut
