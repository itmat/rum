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
    return if $i*2 > $#$self;
    if (&{$$self[0]}($$self[$i],$$self[2*$i]) <= 0 and
	(!defined($$self[2*$i+1]) or
	 &{$$self[0]}($$self[$i],$$self[2*$i+1]) <=0)) {
	return;
    }
    if (defined($$self[2*$i+1]) and 
	&{$$self[0]}($$self[2*$i+1],$$self[2*$i]) <= 0) {
	@$self[$i, 2*$i+1] = @$self[2*$i+1, $i];
	$self->siftDown(2*$i+1);
    }
    else {
	@$self[$i, 2*$i] = @$self[2*$i, $i];
	$self->siftDown(2*$i);
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
    # Use while $i>1 because otherwise we can get $i/2 be 0.
    while ($i > 1 and &{$$self[0]}($$self[$i],$$self[int($i/2)]) < 0) {
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
    $$self[1]=pop @$self;
    $self->siftDown(1);
    return $rv;
}

sub pushon {
    my $self=shift;
    my $val=shift;
    push @$self, $val;
    $self->siftUp($#$self);
}

1;
