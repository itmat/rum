#!/usr/bin/env perl

package RUM::Script::MergeSortedRumFiles;
use strict;
no warnings;
use FindBin qw($Bin);
use lib ("$Bin/../lib", "$Bin/../lib/perl5");
use RUM::Script;
RUM::Script->run_with_logging("RUM::Script::MergeSortedRumFiles");

__END__




=head1 OPTIONS:

=over 4

=item B<-o>, B<--output> F<file> (required)



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

