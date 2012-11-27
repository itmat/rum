package RUM::Mdust;

use strict;
use warnings;
use autodie;

use Carp;

use RUM::BinDeps;
use RUM::Logging;

my $log = RUM::Logging->get_logger;

sub run_mdust {
    my ($filename) = @_;
    my @cmd = (RUM::BinDeps->new->mdust, $filename);
    my $cmd = join ' ', @cmd;
    $log->info("Running mdust: $cmd");
    open my $mdust_out, '-|', $cmd;
    return $mdust_out;
}
    
1;

__END__

=head1 NAME

RUM::Mdust - Interface to mdust

=head1 METHODS

=over 4

=item RUM::Mdust::run_mdust($filename)

Run mdust on the given filename, and return a filehandle that points
to the output of mdust.

=back
