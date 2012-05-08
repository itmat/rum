#!/usr/bin/perl

# Written by Gregory R Grant
# University of Pennsylvania, 2010

use strict;
use warnings;
use FindBin qw($Bin);
use lib ("$Bin/../lib", "$Bin/../lib/perl5");
use RUM::Script;
RUM::Script->run_with_logging("RUM::Script::RumToCov");

=head1 NAME

rum2cov.pl - Generate coverage report for a RUM file

=head1 SYNOPSIS

rum2cov.pl [OPTIONS] -o <coverage_file> <rum_file>

Where <rum file> is the *sorted* RUM_Unique or RUM_NU file. <coverage_file> is the name of the output file, should end in .cov

=head1 DESCRIPTION

Generates a coverage report for a given RUM file. The input file must
be sorted. If it's not, first run sort_RUM_by_location.pl to sort, and
I<do not> use the -separate option.

=head1 OPTIONS

=over

=item B<-o>, B<--output> I<coverage_file>

The output file.

=item B<--name> I<name>

The name of the track.

=item B<--stats> I<stats_file>

Output stats to F<stats_file>, currently just the footprint size.

=back
