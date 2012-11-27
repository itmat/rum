package RUM::Heap;

use strict;

=head1 NAME

RUM::Heap - Heap data structure

=head1 SYNOPSIS

  use RUM::Heap;
 
  # Initialize with a comparator function
  my $heap = RUM::Heap->new(COMPARATOR_FUNCTION);

  # Add some items
  $heap->pushon(ITEM);
  ...

  # Remove some items
  my $item = $heap->poplowest();

=head1 DESCRIPTION

Note: This was pulled out of covmerge.pl. 

This is a general-purpose heap data structure, which can be used as a
priority queue. By default a Heap uses <=> as its comparator function,
though you can initialize it with any consistent comparator function
that takes two arguments and returns a number.

Call B<pushon(ITEM)> to add an item to the heap, and B<poplowest()> to
remove the lowest item.

=head2 Constructor

=over 4

=item RUM::Heap->new($comparator)

Initialize a new heap that uses $comparator->($x, $y) to compare two
elements.

=back

=cut

sub new {
    # TODO: Find out why this is weird when the sentinel is 0!
    # index zero is special.  
    #Oh, we'll put the comparator function there.

    my ($class, $cmp) = @_;
    $cmp ||= sub { return $_[0] <=> $_[1]};

    my $self=[$cmp];
    bless $self;
    return $self;
}


=head2 Methods

=over 4

=item $heap->pushon($item)

Adds the B<$item> to the heap. B<$item> should be an appropriate type
for the comparator function that this heap was initialized with.

=cut

sub pushon {
    my $self=shift;
    my $val=shift;
    push @$self, $val;
    $self->_sift_up($#$self);
}

=item $heap->peek()

Return the minimum item from the heap.

=cut

sub peek {
    my ($self) = @_;
    return $$self[1];
}

=item $heap->poplowest()

Delete and return the minimum item from the heap.

=cut

sub poplowest {
    my $self=shift;
    my $rv=$$self[1];
    if ($#$self<=1) {
	$#$self=0;
	return $rv;
    }
    $$self[1] = pop @$self;

    my $i = 1;
    my $cmp = $self->[0];

    while (1) {

        my $left = $i * 2;
        last if $left > $#$self;
        my $right = $left + 1;
        my $item = $self->[$i];
        if ($cmp->($item,$$self[$left]) <= 0 and
                (!defined($$self[$right]) or
                     $cmp->($item,$$self[$right]) <=0)) {
            last;
        }
        if (defined($$self[$right]) and 
                $cmp->($$self[$right],$$self[$left]) <= 0) {
            $self->[$i] = $self->[$right];
            $self->[$right] = $item;
            $i = $right;
        }
        else {
            $self->[$i] = $self->[$left];
            $self->[$left] = $item;
            $i = $left;
        }
    }

    return $rv;
}

sub _sift_down {
    my $self=shift;
    my $i=int shift;
    my $cmp = $self->[0];

    while (1) {
        my $left = $i * 2;
        return if $left > $#$self;
        my $right = $left + 1;
        my $item = $self->[$i];
        if ($cmp->($item,$$self[$left]) <= 0 and
                (!defined($$self[$right]) or
                     $cmp->($item,$$self[$right]) <=0)) {
            return;
        }
        if (defined($$self[$right]) and 
                $cmp->($$self[$right],$$self[$left]) <= 0) {
            $self->[$i] = $self->[$right];
            $self->[$right] = $item;
            $i = $right;
        }
        else {
            $self->[$i] = $self->[$left];
            $self->[$left] = $item;
            $i = $left;
        }
    }
}

sub _reheap {
    my $self=shift;
    for (my $i=int($#$self/2); $i>=1; $i--) {
	$self->_sift_down($i);
    }
}

sub _sift_up {
    my $self=shift;
    my $i=shift;
    my $cmp = $self->[0];
    # Use while $i>1 because otherwise we can get $i/2 be 0.
    while ($i > 1 and $cmp->($$self[$i],$$self[int($i/2)]) < 0) {
	@$self[$i, int($i/2)] = @$self[int($i/2), $i];
	$i=int($i/2);
    }
}

=back

=cut

1;
