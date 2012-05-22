#!/usr/bin/env perl

use strict;
use warnings;
use FindBin qw($Bin);
use lib ("$Bin/../lib", "$Bin/../lib/perl5");
use RUM::Script;
RUM::Script->run_with_logging("RUM::Script::FinalCleanup");

=head1 NAME

RUM_finalcleanup.pl

=head1 SYNOPSIS

RUM_finalcleanup.pl [OPTIONS] --unique-in <rum_unique> --non-unique-in <rum_nu> --unique-out <cleaned rum_unique outfile> --non-unique-out <cleaned rum_nu outfile> --genome <genome seq> --sam-header <sam header>

=head1 DESCRIPTION

This script modifies the RUM_Unique and RUM_NU files to clean
up things like mismatches at the ends of alignments.

=head1 OPTIONS

=over 4

=item B<--unique-in> I<rum_unique>

=item B<--non-unique-in> I<rum_nu>

Input files of unique non-unique mappers, respectively.

=item B<--genome> I<genome_seq>

File containing genome sequence.

=item B<--unique-out> I<cleaned_rum_unique_outfile>

=item B<--non-unique-out> I<cleaned_rum_nu_outfile>

Files to write cleaned unique and non-unique mappers, respectively.

=item B<--sam-header> I<sam_header>

File to write sam header.

=item B<--faok>

The fasta file already has sequence all on one line.

=item B<--match-length-cutoff> I<n>

Set this min length alignment to be reported.

=item B<-h>, B<--help>

=item B<-v>, B<--verbose>

=item B<-q>, B<--quiet>

=back

=head1 AUTHOR

Gregory Grant (ggrant@grant.org)

=head1 COPYRIGHT

Copyright 2012 University of Pennsylvania

=cut

