#!/usr/bin/perl

# Written by Gregory R. Grant
# Universiity of Pennsylvania, 2010

use strict;
use warnings;
use FindBin qw($Bin);
use lib ("$Bin/../lib", "$Bin/../lib/perl5");
use RUM::Script;
RUM::Script->run_with_logging("RUM::Script::SortRumById");

=head1 NAME

sort_RUM_by_id.pl - Sort a rum file by sequence number

=head1 SYNOPSIS

sort_RUM_by_id.pl [OPTIONS] -o <outfile> <infile>

=head1 DESCRIPTION

This script sorts a RUM output file by sequence number.  It keeps
consistent pairs together.

=head1 OPTIONS

=over 4

=item B<-o>, B<--output> I<outfile>

The output file

=item B<-h>, B<--help>

=item B<-v>, B<--verbose>

=item B<-q>, B<--quiet>

=back

=cut

