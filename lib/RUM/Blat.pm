package RUM::Blat;

use strict;
use warnings;

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

    my $cmd = join ' ', @cmd;

    $log->info("Running blat: @cmd");    
    if (my $pid = fork) {
        open my $fh, '<', $fifo or die "Couldn't open fifo";
        return ($fh, $pid);
    }
    else {
        exec $cmd;
    }
}

1;

=head1 NAME

RUM::Blat - Interface to BLAT

=head1 METHODS

=over 4

=item run_blat(%params)

Run BLAT, and return a filehandle that contains the output streamed
from BLAT. Accepts the following params:

=over 4

=item database

The reference fasta file (genome).

=item query

The query fasta file (reads).

=item blat_args

Extra arguments to pass to blat, as an array ref.

=back

=back

