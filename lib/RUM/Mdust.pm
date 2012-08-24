package RUM::Mdust;

use strict;
use warnings;
use autodie;

use RUM::BinDeps;

use Carp;

sub run_mdust {
    my ($filename) = @_;
    my @cmd = (RUM::BinDeps->new->mdust, $filename);
    my $cmd = join ' ', @cmd;
    open my $mdust_out, '-|', $cmd;
    return $mdust_out;
}
    
1;
