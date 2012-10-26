package RUM::Script::MergeNuStats;

use strict;
no warnings;

use Carp;

use RUM::Logging;

use base 'RUM::Script::Base';

our $log = RUM::Logging->get_logger();

sub summary {
    'Merge two or more non-unique stats files'
}

sub accepted_options {
    return (
        RUM::Property->new(
            opt => 'nu_stats',
            desc => 'Input file',
            nargs => '+',
            handler => \&RUM::Property::handle_multi,
            positional => 1,
            required => 1));
}

sub run {
    my ($self) = @_;
    my @nu_stats = @{ $self->properties->get('nu_stats') };

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
