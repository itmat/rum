package RUM::Blat;

use strict;
use warnings;
use autodie;
use RUM::BinDeps;
use POSIX qw(mkfifo);
use Carp;

sub run_blat {
    my (%params) = @_;

    my @required = ('database', 'query');

    my @missing = grep { ! exists $params{$_} } @required;
    
    if (@missing) {
        croak "Missing required args " . join(', ', @missing);
    }    

    my @blat_args = @{ $params{blat_args} || [] };

    my $temp_file = 'pipe';

    

    mkfifo($temp_file, 0700) or croak "mkfifo($temp_file): $!";
    
    my @cmd = (RUM::BinDeps->new->blat,
               $params{database},
               $params{query},
               $temp_file,
               @blat_args);

    if (my $pid = fork) {
        open my $fh, '<', $temp_file;
        return ($fh, $pid);
    }
    else {
        exec @cmd;
    }
}

1;
