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

sub make_index {
    my ($self) = @_;
    for my $map (values %{ $self->{quants_for_chromosome} }) {
        $map->make_index;
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

sub make_index {
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

        if ($i == $n - 1) {
            return $i;
        }
        
        # The right edge is too far to the right
        if ($pos < $partitions->[$i]) {
            $q = $i - 1;
        }

        # The left edge is too far to the left
        elsif ($partitions->[$i + 1] <= $pos) { 
            $p = $i + 1;
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

        # Find the partition that the start coordinate is located
        # in. $p is an index into @partitions, @partition_features,
        # and @partition_starts.
        my $p = $self->find_partition($start);
        
        # @partition_features->[$p] is an array ref of all the feature
        # IDs that are contained in partition $p. We need to cover all
        # of them.
        for my $fid (@{ $partition_features->[$p] }) {
            $callback->($feature_array->[$fid]) if ! $feature_ids{$fid}++;
        }


        # Now step through all the partitions until we get to the one
        # after the end of my span. Add any features that start in any
        # of those partitions.
        while ($p < @{ $partitions } - 1 && 
               $partitions->[$p + 1] <= $end) {
            $p++;
            for my $fid (@{ $partition_starts->[$p] }) {
                $callback->($feature_array->[$fid]) if ! $feature_ids{$fid}++;
            }
        }
    }

}

=head1 NAME

RUM::QuantMap - Stores quantification counts for features

=head1 SYNOPSIS

  use RUM::QuantMap

  my $quants = RUM::QuantMap->new;

  { # For each feature:
    $quants->add_feature(
      chromosome => $chromosome,
      start      => $start_coord,
      end        => $end_coord,
      data       => $data # Any additional data you want
    );
  }

  $quants->make_index;

  { # For each read:
    my $covered = $quants->cover_features(
      chromosome => $CHR,
           spans => $spans,
        callback => $handler);
  }

=head1 METHODS

=over 4

=item RUM::QuantMap->new

Create a new quant map.

=item $quants->add_feature(params)

Accepts the following params:

=over 4

=item chromosome

 The chromosome that contains the feature

=item start

The start coordinate of the feature

=item end

The end coordinate of the feature

=item data

Any extra data you want to associate with the feature.

=back

=item $quants->make_index

Indicate that you are done adding features, and are ready to start
querying.

Partitions the chromosomes into non-overlapping ranges, and associates
with each range the features that intersect with that range. The
result is that each chromosome has a partition boundery at every
coordinate where a feature starts or ends. This allows is to answer
queries like "what features exist at coordinate x" in O(log(n) + k)
time by performing a binary search on the list of partitions, where n
is the number of partitions, and k is the number of partitions
returned by the query.

=item cover_features(%params)

Takes the following params:

=over 4

=item chromosome

The chromosome that the read is from.

=item spans

The spans of the read, as an array ref of pairs of start/end
coordinates. For example, 1-10, 20-25 would be represented as [[1,
10], [20, 25]].

=item callback

A callback function to call every time we hit a feature that's covered
by this read. It will be called with one parameter: a hash ref to the
feature, as passed in to add_feature. It will have these fields:

=over 4

=over 4

=item chromosome

The chromosome that contains the feature.

=item start

The start coordinate of the feature.

=item end

The end coordinate of the feature.

=item data

Whatever you passed in to add_feature.

=back
  
=back

=back

=item features

Return the list of all features added to the quantification map.

=back
