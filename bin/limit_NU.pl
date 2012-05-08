#!/usr/bin/perl

# Written by Gregory R. Grant
# University of Pennsylvania, 2010

use strict;
use warnings;
use FindBin qw($Bin);
use lib ("$Bin/../lib", "$Bin/../lib/perl5");
use RUM::Script;
RUM::Script->run_with_logging("RUM::Script::LimitNU");

=head1 NAME

limit_NU.pl - Remove non-unique mappers that appear more than a specified number of times.

=head1 SYNOPSIS

limit_NU.pl -o <outfile> -n <cutoff> <rum_nu_file>

=head1 DESCRIPTION

Filters a non-unique mapper file so that alignments for reads for
which the either the forward, or reverse if it is paired-end, appear
more than <cutoff> times file are removed.  Alignments of the joined
reads count as one forward and one reverse.

=head1 OPTIONS

Please provide an input file on the command line and specify the
output file and cutoff with these options:

=over 4

=item B<-o>, B<--output> I<outfile>

The output file.

=item B<-n>, B<--cutoff> I<n>

The threshold.

=item B<-h>, B<--help>

=item B<-v>, B<--verbose>

=item B<-q>, B<--quiet>

=back

=head1 AUTHOR

Gregory Grant (ggrant@grant.org)

=head1 COPYRIGHT

Copyright 2012 University of Pennsylvania

=cut
