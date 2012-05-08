#!/usr/bin/perl

# Written by Gregory R. Grant
# Universiity of Pennsylvania, 2010

use strict;
use warnings;
use FindBin qw($Bin);
use lib ("$Bin/../lib", "$Bin/../lib/perl5");
use RUM::Script;
RUM::Script->run_with_logging("RUM::Script::RemoveDups");

=head1 NAME

removedups.pl - Remove duplicates from a RUM non-unique mapper file

=head1 SYNOPSIS

removedups.pl [OPTIONS] <rum_nu_infile> --non-unique-out <rum_nu_outfile> --unique-out <rum_unique_outfile>

=head1 DESCRIPTION

This was made for the RUM NU file which accrued some duplicates
along its way through the pipeline.

=head1 OPTIONS

Please list the input file on the command line, and indicate locations
for the two output files using these options:

=over 4

=item B<--non-unique-out> I<rum_nu_outfile>

File to write deduplicated non-unique mappers to.

=item B<--unique-out> I<rum_unique_outfile>

If any mappers in the input file are found to be unique after
deduplication, they are appended to this file.

=item B<-h>, B<--help>

=item B<-v>, B<--verbose>

=item B<-q>, B<--quiet>

=back

=head1 AUTHOR

Gregory Grant (ggrant@grant.org)

=head1 COPYRIGHT

Copyright 2012 University of Pennsylvania

=cut
