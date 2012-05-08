#!/usr/bin/perl

# Written by Gregory R Grant
# University of Pennsylvania, 2010

use strict;
use warnings;
use FindBin qw($Bin);
use lib ("$Bin/../lib", "$Bin/../lib/perl5");
use RUM::Script;
RUM::Script->run_with_logging("RUM::Script::MergeNuStats");

=head1 NAME

merge_nu_stats.pl - Merge two or more non-unique stats files

=head1 SYNOPSIS

  merge_nu_stats.pl -n <num_chunks> DIR

=head1 DESCRIPTION

This script will look in <dir> for files named nu_stats.1, nu_stats.2, etc..
up to nu_stats.numchunks, and merge them together to stdout.

=head1 OPTIONS

=over 4

=item B<-n>, B<--chunks> I<num_chunks>

Number of chunks.

=item B<--chunk-ids-file> I<f>

A file mapping chunk N to N.M.  This is used specifically for the RUM
pipeline when chunks were restarted and names changed.

=item B<-h>, B<--help>

=item B<-v>, B<--verbose>

=item B<-q>, B<--quiet>

=cut

