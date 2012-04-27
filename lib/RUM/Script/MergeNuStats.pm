package RUM::Script::MergeNuStats;

use strict;
no warnings;

use Carp;

use RUM::Usage;
use RUM::Logging;
use Getopt::Long;

our $log = RUM::Logging->get_logger();

sub main {

    GetOptions(
        "help|h" => sub { RUM::Usage->help },
        "verbose|v" => sub { $log->more_logging(1) },
        "quiet|q"   => sub { $log->less_logging(1) });

    my @nu_stats = @ARGV;

    $log->info("Merging non-unique stats");

    my %data;

    for my $filename (@nu_stats) {

        open my $in, "<", $filename or croak
            "Couldn't open nu_stats file $filename: $!";

        local $_ = <$in>;

        while ($_ = <$in>) {
            chomp;
            my ($loc, $count) = split /\t/;
            $data{$loc} ||= 0;
            $data{$loc} += $count;
        }
    }

    $log->debug("Data has " . scalar(keys(%data)) . " keys");

    print "\n------------------------------------------\n";
    print "num_locs\tnum_reads\n";
    for (sort {$a<=>$b} keys %data) {
        print "$_\t$data{$_}\n";
    }


}

1;
