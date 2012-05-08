#!/usr/bin/perl

# Written by Gregory R. Grant
# Universiity of Pennsylvania, 2010

use strict;
use warnings;
use FindBin qw($Bin);
use lib ("$Bin/../lib", "$Bin/../lib/perl5");
use RUM::Script;
RUM::Script->run_with_logging("RUM::Script::SortRumByLocation");

=head1 NAME

sort_RUM_by_location.pl - Sort a RUM file by location

=head1 SYNOPSIS

sort_RUM_by_location.pl [OPTIONS] --output <sorted_file> <rum file>

=head1 DESCRIPTION

Sorts sequences a RUM file by mapped location, optionally keeping
forward and reverse reads together.

=head1 OPTIONS

Please provide the F<rum_file> on the command line, where is the
RUM_Unique or RUM_NU file output from the RUM pipeline, and the output
file with B<-o> or B<--output>. Other arguments are optional.

=over 4

=item B<-o>, B<--output> I<sorted_file>

The output file.

=item B<--separate>

Do not necessarily keep forward and reverse reads together. By default
they are kept together.

=item B<--max-chunk-size> I<n>

Maximum number of reads that the program tries to read into memory all
at once. Default is 10,000,000.

=item B<--ram> I<n>

Number of GB of RAM if less than 8, otherwise will assume you have 8,
give or take, and pray... If you have some millions of reads and not
at least 4GB then thisis probably not going to work.

=item B<--allow-small-chunks>

Allow --max-chunk-size to be less than 500,000. This may be useful for
testing purposes.

=back

=head1 AUTHOR

Gregory Grant (ggrant@grant.org)

=head1 COPYRIGHT

Copyright 2012 University of Pennsylvania

=cut


