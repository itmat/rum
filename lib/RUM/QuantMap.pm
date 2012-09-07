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

sub cover_features {
    my ($self, %params) = @_;
    my $chr = delete $params{chromosome};
    if (! defined $chr) {
        carp("QuantMap::cover_features called without chromosome");
    }

    my $map = $self->{quants_for_chromosome}{$chr} or return [];
    return $map->cover_features(%params);
}

sub features {
    my ($self, %params) = @_;
    my $chr = delete $params{chromosome};
    my $map = $self->{quants_for_chromosome}{$chr} or return [];
    return $map->{feature_array};
}

package RUM::SingleChromosomeQuantMap;

use strict;
use warnings;
use Data::Dumper;
my $START = 1;
my $END   = 2;
use List::Util qw(max);
sub new {
    my ($class) = @_;
    my $self = {};
    $self->{features}   = [];
    $self->{partitions} = [];
    $self->{partition_features} = [];
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
    };
    push @{ $self->{features} }, $feature;
}

sub partition {
    my ($self) = @_;

    my @events;

    my @start_events;

    my @features = sort { 
        $a->{start} <=> $b->{start} ||
        $a->{end}   <=> $b->{end} 
    } @{ $self->{features} };

    for my $i (0 .. $#features) {
        $features[$i]{id} = $i;
    }

    $self->{feature_array} = \@features;

    for my $feature (@features) {
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
        push @start_events, $start_event;
        push @events, $start_event, $end_event;
    }

    @events = sort { $a->{loc} <=> $b->{loc} } @events;

    my %current_features;

    my @partitions = (0);
    my @partition_features = ([]);
    my @partition_starts = ([]);


    my $pos = 0;

    while (@events) {
        
        my $loc = $events[0]->{loc};

        my @starts;

        while (@events && ($events[0]->{loc} == $loc)) {
            my $event = shift @events;
            my $feature_id = $event->{feature_id};            
            if ($event->{type} == $START) {
                push @starts, $feature_id;
                $current_features{$feature_id} = 1;
            }
            else {
                delete $current_features{$feature_id};
            }
        }
        
        push @partitions, $loc;
        push @partition_features, [ sort { $a <=> $b } keys %current_features ];
        push @partition_starts, \@starts;
    };

    $self->{partitions}         = \@partitions;
    $self->{partition_features} = \@partition_features;
    $self->{partition_starts}   = \@partition_starts;
}

sub find_partition {
    my ($self, $pos) = @_;

    my $partitions = $self->{partitions};

    my $n = @{ $partitions };

    my ($p, $q) = (0, $n - 1);

    while ($p <= $q) {

        my $i = $p + int(($q - $p) / 2);

        my $this = $partitions->[$i];
        my $next = $partitions->[$i + 1];

        # If I'm too far to the left
        if ($next && $next <= $pos) { 
            $p = $i + 1;
        }

        # I'm too far to the right
        elsif ($pos < $this) {
            $q = $i - 1;
        }
        else {
            return $i;
        }
    }    
    return;
}

sub cover_features {
    my ($self, %params) = @_;

    my $spans    = delete $params{spans};
    my $callback = delete $params{callback};

    my %feature_ids;
    my $partitions         = $self->{partitions};
    my $partition_features = $self->{partition_features};
    my $partition_starts   = $self->{partition_starts};
    my $feature_array      = $self->{feature_array};

    for my $span (@{ $spans }) {

        # The start and end coordinates of this span
        my ($start, $end) = @{ $span };

        my $p = $self->find_partition($start);
        
        for my $fid (@{ $partition_features->[$p] }) {
            $callback->($feature_array->[$fid]) if ! $feature_ids{$fid}++;
        }

        my $q = $p;
        while ($q < @{ $partitions } - 1 && 
               $partitions->[$q + 1] <= $end) {
            $q++;
        }

        for my $i ($p + 1 .. $q) {
            for my $fid (@{ $partition_starts->[$i] }) {
                $callback->($feature_array->[$fid]) if ! $feature_ids{$fid}++;
            }
        }
    }

}

