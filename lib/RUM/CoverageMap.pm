package RUM::CoverageMap;

use strict;
use warnings;

=item new

Create a new RUM::CoverageMap.

=cut

sub new {
    my ($class, $fh) = @_;
    return bless {map => []}, $class;
}

=item read_chromosome($filehandle, $chromosome)

Reads the coverage information for the given $chromosome from the
given $filehandle. $filehandle must point to a file formatted like
RUM_Unique.cov, which must be sorted by chromosome name and start
position. Reads lines until we find one that doesn't match
$chromosome. Returns the number of lines read in.

=cut

sub read_chromosome {
    my ($self, $in, $wanted_chr) = @_;

    local $_;

    my @map;

    while (defined($_ = <$in>)) {
        chomp;

        # Skip over header line
        next if /track type/;

        # File is tab-delimited with four columns
	my ($chr, $start, $end, $cov) = split /\t/;

        # If this is the chromosome we want, add a record to our list,
        # otherwise seek back to the beginning of this line so the
        # next line read will be the first one for the next
        # chromosome.
        if ($chr eq $wanted_chr) {
            # Spans in the file don't include the start position. It's
            # easier for us to store closed ranges, so increment
            # start.
            push @map, [$start + 1, $end, $cov];            
        }
        else {
            my $len = -1 * (1 + length($_));
            seek($in, $len, 1);
            last;
        }
    }
    $self->{map} = \@map;
    $self->{count_coverage_in_span_cache} = {};
    return scalar(@map);
}

=item coverage_span($start, $end)

Query the coverage map for sequences of bases that have the same
coverage within the given [$start, $end] range. Returns a ref to a
list of sub-spans within the given span, where each sub-span has a
count of bases, and the coverage count for those bases. For
example, suppose

  $cm->coverage_span(1000, 1017);

returns

  [[10, 0],
   [5,  1],
   [3,  2]]

This means that the range [1000, 1017] contains 10 bases with 0
coverage followed by 5 with coverage 1, followed by 3 with coverage 2.

=cut

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

=item count_coverage_in_span($start, $end, $cutoff)

Return the number of bases in the span that have coverage no more than
$coverage_cutoff.

=cut

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






# This existed in get_inferred_internal_exons, but it's not used.
#
# sub ave_coverage_in_span {
#     # This will return the number of bases in the span that
#     # have coverage no more than $coverage_cutoff
#     my ($self, $start, $end, $coverage_cutoff) = @_;
#     my $key = $start . ":" . $end . ":" . $coverage_cutoff;

#     if(defined(my $val = $self->{ave_coverage_in_span_cache}{$key})) {
# 	return $val;
#     }

#     my $sum = 0;

#     my $span = $self->coverage_span($start, $end);
    
#     for my $rec (@$span) {
#         my ($n, $cov) = @$rec;
#         $sum += $n * $cov;
#     }
#     my $ave = $sum / ($end - $start + 1);
#     return $self->{ave_coverage_in_span_cache}{$key} = $ave;
# }


# I wrote this method initially, but then replaced ith with span_coverage
#
# sub coverage {
#     my ($self, $pos) = @_;
#     my $map = $self->{map};

#     my $p = 0;
#     my $q = @$map - 1;

#     while ($p <= $q) {

#         my $i = int(($q - $p) / 2);
#         my ($start, $end, $cov) = @{ $map->[$i] };

#         if ($pos < $start) {
#             $q = $i - 1;
#         }
#         elsif ($end < $pos) {
#             $p = $i + 1;
#         }
#         else {
#             return wantarray ? ($cov, $i) : $cov;
#         }
#     }
#     return wantarray ? (0, undef) : 0;
# }



1;

