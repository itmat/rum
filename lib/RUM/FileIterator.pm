package RUM::FileIterator;

use strict;
no warnings;

=head1 NAME

RUM::FileIterator - Functions for iterating over records in RUM_* files

=head1 SYNOPSIS

  use RUM::FileIterator qw(file_iterator peek_it pop_it);

  my $it = file_iterator($file, separate => 1);

  # Take one record at a time 
  while my ($record = pop_it($it)) {
    my $seqnum = $record->{seqnum};
    my $chr    = $record->{chr};
    my $start  = $record->{start};
    my $end    = $record->{end};
    my $seq    = $record->{seq};
  }

=head1 DESCRIPTION

Use file_iterator to open an iterator over records in a RUM_* file,
and then use peek_it and pop_it to look at records and advance through
the iterator. peek_it and pop_it return hash refs that have the following keys:

=over 4

=item B<chr>

The chromosome name.

=item B<seqnum>

The sequence number, e.g. 1234 from seq1234.a.

=item B<start>

The start location.

=item B<end>

The end location.

=item B<entry>

The text of the entry. If this is a pair of a and b reads, this will
be two lines joined together with a newline in between.

=item B<seq>

The sequence in the record.

=back

=head2 Subroutines

=over 4

=cut

use Exporter qw(import);
use Carp;
use RUM::Sort qw(by_location cmpChrs by_chromosome);
use RUM::Heap;
use RUM::Logging;

our $log = RUM::Logging->get_logger();
#use Devel::Size qw(total_size);

our @EXPORT_OK = qw(file_iterator pop_it peek_it sort_by_location
                    merge_iterators);

=item file_iterator(IN, OPTIONS)

Return a new iterator over the open filehandle specified by IN. OPTIONS is a hash, with the following keys:

=over 4

=item B<separate>

Indicates whether it is ok to separate a and b reads. Default is 0.

=back

The only things you should do with the returned iterator are call
peek_it and pop_it on it. IN will be closed when the iterator is
exhausted, so you should probably make sure you pop_it all the way to
the end.

=cut

sub file_iterator {
    my ($in, %options) = @_;
    my $separate = $options{separate};
    
    # Call $nextval immediately so that a call to peek_it will work right
    # away.
    my $next = _read_record($in, %options);
    return sub {
        my $cmd = shift() || "pop";
        if ($cmd eq "peek") {
            return $next;
        }
        elsif ($cmd eq "pop") {
            my $last = $next;
            $next = _read_record($in, %options) if defined($last);
            return $last;
        }
    }
}

=item peek_it(ITERATOR)

Return the next record that would be returned by a call to pop_it,
without actually advancing the iterator. Return undef when there are
no more records.

=cut

sub peek_it {
    my $it = shift;
    croak "I need an iterator" unless ref($it) =~ /CODE/;
    return $it->("peek");
}

=item pop_it(ITERATOR)

Return the next record from the iterator and advance it. Return undef
when there are no more records.

=cut

sub pop_it {
    my $it = shift;
    croak "I need an iterator" unless ref($it) =~ /CODE/;
    return $it->("pop");
}

sub _read_record {
    my ($in, %options) = @_;
    my $separate = $options{separate};
    my $line1 = <$in>;
        
    # When we hit EOF, close the input and return undef for all
    # subsequent values. We're using undef to indicate the end of
    # the iterator.
    unless (defined($line1) and $line1 =~ /\S/) {
        close $in;
        return undef;
    }
    
    chomp($line1);
    
    # This is basically the same as before, but rather than
    # storing the values in several global hashes, we're creating
    # a hash for each element in the iterator, keyed on chr,
    # start, end, and entry.
    my %res;
    my @a = split(/\t/,$line1);
    $res{chr} = $a[1];
    $a[2] =~ /^(\d+)-/;
    $res{start} = int($1);
    $a[0] =~ /(\d+)/;
    $res{seqnum} = int($1);
    $res{seq} = $a[4];
    if ($a[0] =~ /a/ && !$separate) {
        my ($line2, @b, $seqnum2);

        if (defined($line2 = <$in>)) {
            chomp($line2);
            @b = split(/\t/,$line2);
            $b[0] =~ /(\d+)/;
            $seqnum2 = $1;
        }

        if (defined($seqnum2) && $res{seqnum} == $seqnum2 && 
            $b[0] =~ /b/) {
            if($a[3] eq "+") {
                $b[2] =~ /-(\d+)$/;
                $res{end} = $1;
            } else {
                $b[2] =~ /^(\d+)-/;
                $res{start} = int($1);
                $a[2] =~ /-(\d+)$/;
                $res{end} = int($1);
            }
            $res{entry} = $line1 . "\n" . $line2;
        } else {
            $a[2] =~ /-(\d+)$/;
            $res{end} = int($1);
            # reset the file handle so the last line read will be read again
            if (defined($line2)) {
                my $len = -1 * (1 + length($line2));
                seek($in, $len, 1);
            }
            $res{entry} = $line1;
        }
    } else {
        $a[2] =~ /-(\d+)$/;
        $res{end} = int($1);
        $res{entry} = $line1;
    }
    chomp($res{entry});
    
    return \%res;
    
}

=item sort_by_location($in, $out, %options)

Open an iterator over $in, read in all the records, sort them
according to chromosome, start position, end position, and finally
lexicographically, then print them back out. We store the data in a
multilevel hash:

=over 4

=item * 

Hash mapping B<chromosome name> to

=over 4

=item * 

Hashref mapping B<start position> to

=over 4

=item * 

Hashref mapping B<end position> to

=over 4

=item * 

Array ref of B<entries> with this combination of chromosome
name, start, and end.

=back

=back

=back

=back


This takes up almost 1 gb for the non-unique file, and sorts it in
about 1:55. It takes about 3.1 gb for the unique file and sorts it in a little less than 6 minutes.

The old version takes about 1.1 gb for the non-unique file and sorts
it in about 1:55 also. The old version takes about 3.4 gb for the unique file and sorts it in a little more than 6 minutes.

=cut
sub sort_by_location {
    my ($in, $out, %options) = @_;
    my $max = $options{max};
    my $file_end = $options{end};

    # Open an iterator over the input file.
    my $it = ref($in) =~ /CODE/ ? $in : file_iterator($in, %options);

    # Fill up @recs by repeatedly popping the iterator until it is
    # empty. See RUM::FileIterator.
    my @recs;
    my %data;
    my $count = 0;
    $log->debug("Reading file");
    while (my $rec = pop_it($it)) {
        my %rec = %$rec;
        my $chr = delete $rec{chr};
        my $start = delete $rec{start};
        my $end   = delete $rec{end};
        $data{$chr} ||= {};
        $data{$chr}{$start} ||= {};
        $data{$chr}{$start}{$end}   ||= [];
        push @{ $data{$chr}{$start}{$end} }, $rec{entry};
        if ($max && ($count++ >= $max)) {
            last;
        }
        if ($file_end && tell($in) > $file_end) {
            $log->debug("Stopping because file position ".tell($in)." is past $file_end")
                if $log->is_debug;
            last;
        }
    }
    $log->debug("Done reading");
#    my $size = total_size(\%data);
#    printf "Size of recs: %d or %.2f per rec\n", $size, $size / $count;

    # Sort the records by location (See RUM::Sort for by_location) and
    # print them.
    for my $chr (sort by_chromosome keys(%data)) {
        my $with_this_chr = $data{$chr};
        for my $start (sort { $a <=> $b } keys %$with_this_chr) {
            my $with_this_start = $with_this_chr->{$start};
            for my $end (sort { $a <=> $b } keys %$with_this_start) {
                my $with_this_end = $with_this_start->{$end};
                for my $entry (sort @$with_this_end) {
                    print $out "$entry\n";                    
                }
            }
        }
    }
    return $count;
}

=item merge_iterators(CMP, OUT_FH, ITERATORS)

=item merge_iterators(OUT_FH, ITERATORS)

Merges the given ITERATORS together, printing the entries in the
iterators to OUT_FH. We assume that the ITERATORS are producing entries in sorted order.

If CMP is supplied, it must be a comparator function; otherwise
by_location will be used.

=cut

sub merge_iterators {
    
    my ($outfile, @iters) = @_;

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
        if (my $rec = $iter->("pop")) {
            $chr[$i]   = $rec->{chr};
            $start[$i] = $rec->{start};
            $end[$i]   = $rec->{end};
            $entry[$i] = $rec->{entry};
            $q->pushon($i);
            $i++;
        }
    }

    # Repeatedly take the iterator with the lowest next record from
    # the queue, print the record, and then add the iterator back
    # unless it is empty.
    while (defined(my $index = $q->poplowest())) {
        print $outfile "$entry[$index]\n";
        if (my $rec = $iters[$index]->("pop")) {
            $chr[$index]   = $rec->{chr};
            $start[$index] = $rec->{start};
            $end[$index]   = $rec->{end};
            $entry[$index] = $rec->{entry};
            $q->pushon($index);
        } else {
            $log->debug("Exhausted an iterator");
        }
    }
}

=back

=cut



1;
