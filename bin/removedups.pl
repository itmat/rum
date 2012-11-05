#!/usr/bin/perl

# Written by Gregory R. Grant
# Universiity of Pennsylvania, 2010

use strict;
use warnings;
use FindBin qw($Bin);
use lib ("$Bin/../lib", "$Bin/../lib/perl5");
use RUM::Script::RemoveDups;
RUM::Script::RemoveDups->main;


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
