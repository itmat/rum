package RUM::Blat;

use strict;
use warnings;
use autodie;

use File::Temp qw(tempdir);
use RUM::BinDeps;
use POSIX qw(mkfifo);
use Carp;

my $log = RUM::Logging->get_logger;

sub run_blat {
    my (%params) = @_;

    my @required = ('database', 'query');

    my @missing = grep { ! exists $params{$_} } @required;
    
    if (@missing) {
        croak "Missing required args " . join(', ', @missing);
    }    

    my @blat_args = @{ $params{blat_args} || [] };

    my $temp_file = 'pipe';

    

    my $dir = tempdir(CLEANUP => 1);
    my $fifo = "$dir/blat_output";
    $log->debug("Making fifo at $fifo");
    mkfifo($fifo, 0700) or croak "mkfifo($fifo): $!";
    
    my @cmd = (RUM::BinDeps->new->blat,
               $params{database},
               $params{query},
               $fifo,
               @blat_args);

    $log->debug("Execing @cmd");    
    if (my $pid = fork) {
        open my $fh, '<', $fifo;
        return ($fh, $pid);
    }
    else {
        exec @cmd;
    }
}

1;
