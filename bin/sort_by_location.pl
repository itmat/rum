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

  sort_by_location.pl [OPTIONS] -o <out_file> --location <loc_col> <INPUT>
  sort_by_location.pl [OPTIONS] -o <out_file> --chromosome <chr_col> --start <start_col> --end <end_col> <INPUT>

=head1 ARGUMENTS

<INPUT> is a tab-delimited file with either one column giving
locations in the format chr:start-end, or with chr, start location,
and end location given in three different columns.

You must always specify an output file with B<-o> or B<--output>.

If your input file has a single column in the format chr:start-end,
you must specify:

=over 4

=item B<--location> I<loc_col>

The column that specifies the location if using chr:start-end format,
counting from 1.

=back

Otherwise if your input file has separate chromosome, start, and end columns, you must provide these three arguments:

=over 4

=item B<--chromosome> I<chr_col>

=item B<--start> I<start_col>

=item B<--end> I<end_col>

The columns that specify the chromosome, start location, and end
location, all counting from 1.

=back

=head2 Optional arguments

=over 4

=item B<--skip> I<n>

Skip the first n lines (will preserve those lines at the top of the
output).

=back

