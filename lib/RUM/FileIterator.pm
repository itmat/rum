package RUM::FileIterator;

use strict;
use warnings;

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

our @EXPORT_OK = qw(file_iterator pop_it peek_it);

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
    $res{start} = $1;
    $a[0] =~ /(\d+)/;
    $res{seqnum} = $1;
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
                $res{start} = $1;
                $a[2] =~ /-(\d+)$/;
                $res{end} = $1;
            }
            $res{entry} = $line1 . "\n" . $line2;
        } else {
            $a[2] =~ /-(\d+)$/;
            $res{end} = $1;
            # reset the file handle so the last line read will be read again
            my $len = -1 * (1 + length($line2));
            seek($in, $len, 1);
            $res{entry} = $line1;
        }
    } else {
        $a[2] =~ /-(\d+)$/;
        $res{end} = $1;
        $res{entry} = $line1;
    }
    chomp($res{entry});
    
    return \%res;
    
}

=back

=cut

1;
