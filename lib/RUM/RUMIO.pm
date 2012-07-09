package RUM::RUMIO;

use strict;
use warnings;

use base 'RUM::AlignIO';

use Data::Dumper;

use RUM::Logging;
use RUM::Sort qw(by_chromosome);
use RUM::Heap;
use RUM::Sort qw(cmpChrs);

use Carp;

our $log = RUM::Logging->get_logger;

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(%options);
    $self->{strand_last} = $options{strand_last};
    return $self;
}

sub parse_locs {
    my ($self, $locs) = @_;
    [ map { [split /-/] } split /,\s*/, $locs ];
}

sub parse_aln {
    my ($self, $line) = @_;
    
    my ($readid, $chr, $locs, $strand, $seq) = split /\t/, $line;
    $locs or croak "Got empty location in line '$line' (line number " 
    . $self->filehandle->input_line_number . ")";

    ($strand, $seq) = ($seq, $strand) if $self->{strand_last};

    return RUM::Alignment->new(readid => $readid,
                               chr    => $chr,
                               locs   => $self->parse_locs($locs),
                               strand => $strand,
                               seq    => $seq,
                               raw    => $line);
}

sub format_locs {
    my ($self, $aln) = @_;
    my $locs = $aln->locs;
    join(", ", map("$_->[0]-$_->[1]", @$locs));
}

sub format_aln {
    my ($self, $aln) = @_;
    my ($readid, $chr, $locs, $strand, $seq) = 
        @$aln{qw(readid chr locs strand seq)};
    ($strand, $seq) = ($seq, $strand) if $self->{strand_last};
    $locs = join(", ", map("$_->[0]-$_->[1]", @$locs));
    my $result = join("\t", $readid, $chr, $locs, $strand, $seq);
    return $result;
}

sub pair_range {
    my ($class, $fwd, $rev) = @_;

    return ($fwd->start, $fwd->end) unless $rev;
    return ($fwd->start, $rev->end) if $fwd->strand eq '+';
    return ($rev->start, $fwd->end);
}

=over 4

=item sort_by_location($in, $out, %options)

Open an iterator over $in, read in all the records, sort them
according to chromosome, start position, end position, and finally
lexicographically, then print them back out.

=cut

sub sort_by_location {
    my ($class, $in, $out, %options) = @_;

    confess "I need a RUM::Iterator, got $in" unless $in->isa("RUM::Iterator");

    my $max = $options{max};
    my $file_end = $options{end};

    # Fill up @recs by repeatedly popping the iterator until it is
    # empty. See RUM::FileIterator.
    my @recs;

    # We store the data in a multilevel hash:
    
    # $chromosome_name
    #   $start_pos
    #     $end_pos
    #       $raw_entry1,
    #       $raw_entry2,
    #       ...,
    #       $raw_entry_n

    my %data;
    my $count = 0;
    $log->debug("Reading now");
    while (my $pair = $in->next_val) {
        $pair = $pair->to_array;
        my ($fwd, $rev) = @{ $pair };
        my $chr = $fwd->chromosome;
        my ($start, $end) = $class->pair_range($fwd, $rev);

        my @entries = map { $_->raw . "\n" } @{ $pair };


        $data{$chr} ||= {};
        $data{$chr}{$start} ||= {};
        $data{$chr}{$start}{$end}   ||= [];
        push @{ $data{$chr}{$start}{$end} }, join("", @entries);
        if ($max && ($count++ >= $max)) {
            last;
        }
        if ($file_end && tell($in) > $file_end) {
            $log->debug("Stopping because file position ".tell($in)." is past $file_end")
                if $log->is_debug;
            last;
        }
    }

    # Sort the records by location (See RUM::Sort for by_location) and
    # print them.
    for my $chr (sort by_chromosome keys(%data)) {
        my $with_this_chr = $data{$chr};
        for my $start (sort { $a <=> $b } keys %$with_this_chr) {
            my $with_this_start = $with_this_chr->{$start};
            for my $end (sort { $a <=> $b } keys %$with_this_start) {
                my $with_this_end = $with_this_start->{$end};
                for my $entry (sort @$with_this_end) {
                    print $out $entry;
                }
            }
        }
    }
    return $count;
}

=item merge_iterators(CMP, OUT_FH, ITERATORS)

=item merge_iterators(OUT_FH, ITERATORS)

Merges the given ITERATORS together, printing the entries in the
iterators to OUT_FH. We assume that the ITERATORS are producing
entries in sorted order.

If CMP is supplied, it must be a comparator function; otherwise
by_location will be used.

=cut

sub merge_iterators {
    
    my ($class, $outfile, @iters) = @_;

    my (@chr, @start, @end, @entry);

    my $cmp = sub {
        my $c = shift;
        my $d = shift;
        if ($chr[$c] eq $chr[$d]) {
            return 
                $start[$c] <=> $start[$d] ||
                  $end[$c] <=> $end[$d] ||
                $entry[$c] cmp $entry[$d];
        }
        return cmpChrs($chr[$c], $chr[$d]);
    };

    # Use a priority queue to store the iterators. The key function
    # takes two iterators, peeks at the next record each iterator has,
    # and compares them by location. This maintains the list of
    # iterators in sorted order according to the next record from each
    # one.
    my $q = RUM::Heap->new($cmp);

    # Populate the queue, skipping any iterators that are already exhausted.
    my $i = 0;
    for my $iter (@iters) {
        if (my $aln = $iter->next_val) {
            my ($start, $end) = @{ $aln->locs->[0] };
            $chr[$i]   = $aln->chromosome;
            $start[$i] = $start;
            $end[$i]   = $end;
            $entry[$i] = $aln->raw;
            $q->pushon($i);
            $i++;
        }
    }

    # Repeatedly take the iterator with the lowest next record from
    # the queue, print the record, and then add the iterator back
    # unless it is empty.
    while (defined(my $index = $q->poplowest())) {
        print $outfile "$entry[$index]\n";
        my $iter = $iters[$index];
        if (my $aln = $iter->next_val) {
            my ($start, $end) = @{ $aln->locs->[0] };
            $chr[$index]   = $aln->chromosome;
            $start[$index] = $start;
            $end[$index]   = $end;
            $entry[$index] = $aln->raw;
            $q->pushon($index);
        } else {
            $log->debug("Exhausted an iterator");
        }
    }
}

=back

=cut

1;
