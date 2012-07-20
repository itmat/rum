package RUM::Script::MergeNuStats;

use strict;
no warnings;
use autodie;

use Carp;

use base 'RUM::Script::Base';

sub main {

    my $self = __PACKAGE__->new;
    $self->get_options;

    my @nu_stats = @ARGV;

    $self->logger->info("Merging non-unique stats");

    my %data;

    for my $filename (@nu_stats) {

        open my $in, "<", $filename;

        local $_ = <$in>;

        while ($_ = <$in>) {
            chomp;
            my ($loc, $count) = split /\t/;
            $data{$loc} ||= 0;
            $data{$loc} += $count;
        }
    }

    $self->logger->debug("Data has " . scalar(keys(%data)) . " keys");

    print "\n------------------------------------------\n";
    print "num_locs\tnum_reads\n";
    for (sort {$a<=>$b} keys %data) {
        print "$_\t$data{$_}\n";
    }


}

1;

__END__

=head1 NAME

RUM::Script::MergeNuStats

=head1 METHODS

=over 4

=item RUM::Script::MergeNuStats->main

Run the script.

=back

=head1 AUTHORS

Gregory Grant (ggrant@grant.org)

Mike DeLaurentis (delaurentis@gmail.com)

=head1 COPYRIGHT

Copyright 2012, University of Pennsylvania


