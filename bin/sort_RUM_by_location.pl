#!/usr/bin/perl

# Written by Gregory R. Grant
# Universiity of Pennsylvania, 2010

use strict;
use warnings;
use FindBin qw($Bin);
use lib ("$Bin/../lib", "$Bin/../lib/perl5");
use RUM::Script;
RUM::Script->run_with_logging("RUM::Script::SortRumByLocation");



=item B<--max-chunk-size> I<n>

Maximum number of reads that the program tries to read into memory all
at once. Default is 10,000,000.

=item B<--allow-small-chunks>

Allow --max-chunk-size to be less than 500,000. This may be useful for
testing purposes.

=back

=head1 AUTHOR

Gregory Grant (ggrant@grant.org)

=head1 COPYRIGHT

Copyright 2012 University of Pennsylvania

=cut


