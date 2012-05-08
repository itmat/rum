#!/usr/bin/perl

# Written by Gregory R Grant
# University of Pennsylvania, 2010

use strict;
use warnings;
use FindBin qw($Bin);
use lib ("$Bin/../lib", "$Bin/../lib/perl5");
use RUM::Script;
RUM::Script->run_with_logging("RUM::Script::MergeChrCounts");

=head1 NAME

merge_chr_counts.pl - Merge two or more chr counts files

=head1 SYNOPSIS

  merge_chr_counts.pl -o <outfile> IN_FILES

Where IN_FILES are chr_counts files.

=head1 OPTIONS

=over 4

=item B<-o>, B<--output> I<outfile>

Output file.

=item B<--chunk-ids-file> I<f>

A file mapping chunk N to N.M.  This is used specifically for the RUM
pipeline when chunks were restarted and names changed.

=item B<-h>, B<--help>

=item B<-v>, B<--verbose>

=item B<-q>, B<--quiet>

=cut
