package RUM::CoverageMap;

use strict;
use warnings;

use Carp;
use Data::Dumper;

sub new {
    my ($class, $fh) = @_;

    return bless {
        fh  => $fh,
        map => [],
        count_coverage_in_span_cache => {}
    }, $class;
}



sub read_chromosome {
    my ($self, $wanted_chr) = @_;
    my $fh = $self->{fh};
    local $_;

    my @map;
    my $last_end = -1;
    while (defined($_ = <$fh>)) {
        chomp;

        # Skip over header line
        next if /track type/;

        # File is tab-delimited with four columns
	my ($chr, $start, $end, $cov) = split /\t/;

        # If this is not the chromosome we want, seek back to the
        # beginning of this line so it will be read again for the next
        # chromosome.
        if ($chr ne $wanted_chr) {
            my $len = -1 * (1 + length($_));
            seek($fh, $len, 1);
            last;
        }

        # Validate the input
        $end - $start > 0 or croak "Invalid span on line $.: $_";
        $start >= $last_end or croak
            "Error with the coverage file: apan on line $. overlaps previous ".
                "span";
        $last_end = $end;

        # Spans in the file don't include the start position. It's
        # easier for us to store closed ranges, so increment
        # start.
        push @map, [$start + 1, $end, $cov];            
    }
    $self->{map} = \@map;
    $self->{count_coverage_in_span_cache} = {};
    return scalar(@map);
}

sub coverage_span {
    my ($self, $start, $end) = @_;
    my $map = $self->{map};

    # Do a binary search to find the the lowest span in our array
    # that is contained in the caller's query.
    my ($p, $q) = (0, $#$map);
    my $start_idx;
    while (!defined($start_idx) && $p <= $q) {
        my $i = $p + int(($q - $p) / 2);
        my ($r_start, $r_end) = @{ $map->[$i] };
        if    ($start < $r_start) { $q = $i - 1 }
        elsif ($r_end < $start)   { $p = $i + 1 }
        else                  { $start_idx = $i }
    }    
    $start_idx ||= $p;

    # Do a similar binary search to find the highest span
    ($p, $q) = (0, $#$map);
    my $end_idx;
    while (!defined($end_idx) && $p <= $q) {
        my $i = $p + int(($q - $p) / 2);
        my ($r_start, $r_end) = @{ $map->[$i] };
        if    ($end < $r_start) { $q = $i - 1 }
        elsif ($r_end < $end)   { $p = $i + 1 }
        else                  { $end_idx = $i }
    }    
    $end_idx ||= $q;

    my @result;

    my $last_end = $start - 1;

    # For each span in my array that's inside the query range
    for my $i ($start_idx .. $end_idx) {
        
        # Unpack the record for the span: start, end, and coverage
        my ($r_start, $r_end, $cov) = @{ $map->[$i] };
        
        # Calculate the size $n of the overlap between this span and
        # the query region
        my $p = $start < $r_start ? $r_start : $start;
        my $q = $end   < $r_end   ? $end     : $r_end;
        my $n = $q - $p + 1;

        # If there is a gap between the previous span and this one,
        # fill it with an appropriately sized span of 0 coverage
        if ($r_start - $last_end > 1) {
            push @result, [$r_start - $last_end - 1, 0];
        }

        $last_end = $r_end;
        push @result, [$n, $cov];
    }

    # If we didn't find anything, return a single span of 0 coverage
    if (!@result) {
        push @result, [$end - $start + 1, 0];
    }

    # If there's a gap between the last span I found and the end of
    # the query, pad it with a span of 0 coverage
    elsif ($end > $map->[$end_idx][1]) {
        push @result, [$end - $map->[$end_idx][1], 0];
    }

    return \@result;
}

sub count_coverage_in_span {

    my ($self, $start, $end, $coverage_cutoff) = @_;
    my $key = $start . ":" . $end . ":" . $coverage_cutoff;

    if(defined(my $val = $self->{count_coverage_in_span_cache}{$key})) {
	return $val;
    }

    my $num_below=0;

    my $span = $self->coverage_span($start, $end);
    
    for my $rec (@$span) {
        my ($n, $cov) = @$rec;
        if ($cov < $coverage_cutoff) {
            $num_below += $n;
        }
    }
    return $self->{count_coverage_in_span_cache}{$key} = $num_below;
}

1;

__END__

=head1 NAME

RUM::CoverageMap - Map a coordinate to its coverage

=head1 CONSTRUCTORS

=over 4

=item new

Create a new RUM::CoverageMap that reads from the given $filehandle,
which must point to a file formatted like RUM_Unique.cov. Records must
be tab-delimited with four columns: I<chromosome>, I<start>, I<end>,
and I<coverage>. Records must be sorted by I<chromosome> first and
then by I<start>. I<start> must be less than I<end>, and there must
not be any overlapping spans in the same chromosome.

TODO: We can probably change the data structure to relax some of these
restrictions if that turns out to be useful.

=back

=head1 METHODS

=over 4

=item read_chromosome($filehandle, $chromosome)

Reads the coverage information for the given $chromosome from the
given $filehandle. Reads lines until we find one that doesn't match
$chromosome. Returns the number of lines read in.

=item coverage_span($start, $end)

Query the coverage map for coverage information within the given
[$start, $end] range. The results are returned as an array ref of
array refs, each representing a sub-span of bases that have the same
coverage. Each sub-span is reported as a tuple of the number of bases
it contains and the coverage for those bases. For example, suppose

  $cm->coverage_span(1000, 1017);

returns

  [[10, 0],
   [5,  1],
   [3,  2]]

This means that the range [1000, 1017] contains 10 bases with 0
coverage followed by 5 with coverage 1, followed by 3 with coverage 2.

=item count_coverage_in_span($start, $end, $cutoff)

Return the number of bases in the span that have coverage no more than
$coverage_cutoff.

=cut

