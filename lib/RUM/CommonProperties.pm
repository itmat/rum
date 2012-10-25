package RUM::CommonProperties;

use strict;
use warnings;

sub read_type {
    return RUM::Property->new(
        opt => 'type=s',
        desc => 'Whether the input contains single or paired reads',
        required => 1,
        choices => ['single', 'paired']
    );
}

sub max_pair_dist {
    return RUM::Property->new(
        opt => 'max-pair-dist=s',
        desc => 'Maximum distance between paired reads',
        default =>  500000);
}

sub genome_size {
    return RUM::Property->new(
        opt => 'genome-size=s',
        desc => 'Size of the genome',
        check => \&check_int_gte_1);
}

sub check_int_gte_1 {
    my ($props, $prop, $val) = @_;
    if (defined($val)) {
        if ($val !~ /^\d+$/ ||
            int($val) < 1) {
            $props->errors->add($prop->options . " must be an integer greater than 1");
        }
    }
}

1;
