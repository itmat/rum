package RUM::QuantMap;

use strict;
use warnings;

use Data::Dumper;

my $START = 1;
my $END   = 2;

sub new {
    my ($class) = @_;
    my $self = {};
    $self->{features}   = {};
    $self->{partitions} = [];
    $self->{counter}    = 1;
    return bless $self, $class;
}

sub add_feature {
    my ($self, %params) = @_;

    my $start = delete $params{start};
    my $end   = delete $params{end};
    my $data  = delete $params{data};

    my $id = $self->{counter}++;

    my $feature = {
        start => $start,
        end   => $end,
        data  => $data,
        id    => $id
    };
    $self->{features}{$id} = $feature;
}



sub partition {
    my ($self) = @_;

    my @events;

    for my $feature (values %{ $self->{features} }) {
        my $start_event = {
            type => $START,
            loc  => $feature->{start},
            feature_id => $feature->{id}
        };
        
        my $end_event = {
            type => $END,
            loc  => $feature->{end},
            feature_id => $feature->{id}
        };

        push @events, $start_event, $end_event;
    }

    @events = sort { $a->{loc} <=> $b->{loc} } @events;

    my %current_features;

    my @partitions = ({ start => 0, features => []}); 

    my $pos = 0;

    while (my $event = shift @events) {
        
        my $feature_id = $event->{feature_id};

        if ($event->{type} == $START) {
            $current_features{$feature_id} = 1;
        }
        else {
            delete $current_features{$feature_id};
        }

        push @partitions, {
            start => $event->{loc},
            features => [ keys %current_features ]
        };

    }

    $self->{partitions} = \@partitions;
    
}

sub find_partition {
    my ($self, $pos) = @_;

    my $partitions = $self->{partitions};

    my $n = @{ $partitions };

    my ($p, $q) = (0, $n - 1);

    while ($p <= $q) {
        warn "For $pos, P is $p, Q is $q\n";
        my $i = $p + int(($q - $p) / 2);

        my $this = $partitions->[$i];
        my $next = $i < $n ? $partitions->[$i + 1] : undef;

        # If I'm too far to the left
        if ($next && $next->{start} < $pos) { 
            $p = $i + 1;
        }
        elsif ($pos < $this->{start}) {
            $q = $i - 1;
        }
        else {
            return $i;
        }
    }    
    return;
}

sub covered_features {
    my ($self, %params) = @_;

    my $start = delete $params{start};
    my $end   = delete $params{end};

    my $p = $self->find_partition($start);
    my $q = $self->find_partition($end);

    print "P and q are $p, $q\n";
    my %feature_ids;

    for my $i ( $p .. $q ) {
        my $partition = $self->{partitions}[$i];
        for my $feature_id ( @{ $partition->{features} } ) {

            $feature_ids{$feature_id} = 1;
        }
    }

    my @features;
    for my $id (keys %feature_ids) {
        push @features, $self->{features}{$id};
    }
    return \@features;
}
