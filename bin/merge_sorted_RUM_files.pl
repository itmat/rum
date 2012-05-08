#!/usr/bin/env perl

package RUM::Script::MergeSortedRumFiles;
use strict;
no warnings;
use FindBin qw($Bin);
use lib ("$Bin/../lib", "$Bin/../lib/perl5");
use RUM::Script;
RUM::Script->run_with_logging("RUM::Script::MergeSortedRumFiles");

__END__

=head1 NAME

merge_sorted_RUM_files.pl - Merge sorted RUM files

=head1 SYNOPSIS

  merge_sorted_RUM_files.pl [OPTIONS] -o <outfile> <infile1> [...<infileN>]
  merge_sorted_RUM_files.pl --help

where infiles are RUM_Unique or RUM_NU files, each sorted by location,
without the forward and reverse reads separated.  They will be merged
into a single sorted file output to <outfile>.

=head1 OPTIONS:

=over 4

=item B<-o>, B<--output> F<file> (required)

The file to write the merged results to.

=item B<--chunk-ids-file> F<file> 

A file mapping chunk N to N.M.  This is used specifically for the RUM
pipeline when chunks were restarted and names changed.

=item B<-v>, B<--verbose>

Be verbose.

=item B<-q>, B<--quiet>

Be quiet.

=item B<-h>, B<--help>

Print help.

=cut

