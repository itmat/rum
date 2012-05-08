#!/usr/bin/perl

# Written by Gregory R Grant
# University of Pennsylvania, 2010

use strict;
use warnings;
use FindBin qw($Bin);
use lib ("$Bin/../lib", "$Bin/../lib/perl5");
use RUM::Script;
RUM::Script->run_with_logging("RUM::Script::SortByLocation");

=head1 NAME

sort_by_location.pl - Sort a file by location

=head1 SYNOPSIS

sort_by_location.pl [OPTIONS] -o <out_file> --location <loc_col> INPUT

sort_by_location.pl [OPTIONS] -o <out_file> --chromosome <chr_col> --start <start_col> --end <end_col> INPUT

=head1 OPTIONS

=over

=item B<-o>, B<--output> I<out_file>

The output file.

=item B<--location> I<n>

The column number that has the location (start counting at one). This
column must have the form chr:start-end.

=item B<--chromosome> I<n>

The column that has the chromosome (start counting at one).

=item B<--start> I<n>

The column that has the start location (start counting at one).

=item B<--end> I<n>

The column that has the end location (start counting at one).

=item B<--skip> I<n>

Skip the first n lines (will preserve those lines at the top of the output).

=cut
