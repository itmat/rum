package RUM::Heap;

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

sub siftDown {
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

sub reheap {
    my $self=shift;
    for (my $i=int($#$self/2); $i>=1; $i--) {
	$self->siftDown($i);
    }
}

sub siftUp {
    my $self=shift;
    my $i=shift;
    my $cmp = $self->[0];
    # Use while $i>1 because otherwise we can get $i/2 be 0.
    while ($i > 1 and $cmp->($$self[$i],$$self[int($i/2)]) < 0) {
	@$self[$i, int($i/2)] = @$self[int($i/2), $i];
	$i=int($i/2);
    }
}

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

sub pushon {
    my $self=shift;
    my $val=shift;
    push @$self, $val;
    $self->siftUp($#$self);
}

1;
