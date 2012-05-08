#!/usr/bin/perl

# Written by Gregory R. Grant
# University of Pennsylvania, 2010

use strict;
use warnings;
use FindBin qw($Bin);
use lib ("$Bin/../lib", "$Bin/../lib/perl5");
use RUM::Script;
RUM::Script->run_with_logging("RUM::Script::GetNuStats");

=head1 NAME

get_nu_stats.pl - Read a sam file and print counts for non-unique mappers

=head1 OPTIONS

=over 4

=item B<-o>, B<--output> I<out_file>

The output file. Defaults to stdout.

=back

=head1 AUTHOR

Gregory Grant (ggrant@grant.org)

=head1 COPYRIGHT

Copyright 2012 University of Pennsylvania

=cut
