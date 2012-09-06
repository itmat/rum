package RUM::QuantMap;

use strict;
use warnings;

use Carp;

sub new {
    my ($class) = @_;
    my $self = {};
    $self->{quants_for_chromosome} = {};
    return bless $self, $class;
}

sub add_feature {
    my ($self, %params) = @_;
    my $chr = delete $params{chromosome};
    my $map = $self->{quants_for_chromosome}{$chr} ||= RUM::SingleChromosomeQuantMap->new;
    $map->add_feature(%params);
}

sub partition {
    my ($self) = @_;
    for my $map (values %{ $self->{quants_for_chromosome} }) {
        $map->partition;
    }
}

sub covered_features {
    my ($self, %params) = @_;
    my $chr = delete $params{chromosome};
    if (! defined $chr) {
        carp("QuantMap::covered_features called without chromosome");
    }

    my $map = $self->{quants_for_chromosome}{$chr} or return [];
    return $map->covered_features(%params);
}

sub features {
    my ($self, %params) = @_;
    my $chr = delete $params{chromosome};
    my $map = $self->{quants_for_chromosome}{$chr} or return [];
    return [ values %{ $map->{features} } ];
}

package RUM::SingleChromosomeQuantMap;

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
            loc  => $feature->{end} + 1,
            feature_id => $feature->{id}
        };

        push @events, $start_event, $end_event;
    }

    @events = sort { $a->{loc} <=> $b->{loc} } @events;

    my %current_features;

    my @partitions = ({ start => 0, features => []}); 

    my $pos = 0;

    while (@events) {
        
        my $loc = $events[0]->{loc};

        while (@events && ($events[0]->{loc} == $loc)) {
            my $event = shift @events;
            my $feature_id = $event->{feature_id};            
            if ($event->{type} == $START) {
                $current_features{$feature_id} = 1;
            }
            else {
                delete $current_features{$feature_id};
            }
        }

        push @partitions, {
            start => $loc,
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

        my $i = $p + int(($q - $p) / 2);

        my $this = $partitions->[$i];
        my $next = $i < $n ? $partitions->[$i + 1] : undef;

        # If I'm too far to the left
        if ($next && $next->{start} <= $pos) { 
            $p = $i + 1;
        }

        # I'm too far to the right
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

    my $spans = delete $params{spans};

    my %feature_ids;

    for my $span (@{ $spans }) {

#        print "Looking for span " . Dumper($span);


        my ($start, $end) = @{ $span };

        my $p = $self->find_partition($start);
        my $q = $self->find_partition($end);
 #       print "  p is " . Dumper($self->{partitions}[$p]);
 #       print "  q is " . Dumper($self->{partitions}[$q]);

        for my $i ( $p .. $q ) {
            my $partition = $self->{partitions}[$i];


            for my $feature_id ( @{ $partition->{features} } ) {
                
                $feature_ids{$feature_id} = 1;
            }
        }
    }

    my @features;
    for my $id (keys %feature_ids) {
        push @features, $self->{features}{$id};
    }
    return \@features;
}

