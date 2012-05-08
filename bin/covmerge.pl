#!/usr/bin/perl

# Merge two coverage files.

use strict;

use FindBin qw($Bin);
use lib ("$Bin/../lib", "$Bin/../lib/perl5");

use RUM::Common qw(roman Roman isroman arabic);
use RUM::Sort qw(cmpChrs);

my $name="Coverage";
use Getopt::Long;
my $result;
$result=GetOptions("name=s" => \$name);

if (!$result or @ARGV<2) {
    print "Usage: $0 [--name=<name for graph>] <file> <file> ...
\tMerge at least two coverage files onto standard output.
\tYou might need to quote the name if it has spaces, etc.\n";
    exit(1);
}
$|=1;
# use Dbg;

my @files=@ARGV;
print "track type=bedGraph name=\"$name\" description=\"$name\" visibility=full color=255,0,0 priority=10\n";
my @handles=();
foreach my $file (@files) {
    my $fh;
    open $fh, $file or die("Couldn't open $file");
    push @handles, $fh;
}

my $chr=undef;			# chromosome
my $incchr=undef;		# Incoming chromosome
my $currentfile=undef;		# Which file did the currentspan's end come from
my @incomingspan=();

sub combinespans {
    my @spans=@_;
    my ($span1, $span2)=@_;	# They're references, mind!
    # Takes two spans, returns a list of three: pre-overlap, overlap,
    # and post-overlap.  The first two should be output, and the third
    # retained for next time.
    # The spans are *full* spans, including the chromosome name now.
    #%# dbg("\tCombining (",join(",",@$span1),") and (",join(",",@$span2),")\n");
    my $comp=calledCmpChrs($$span1[0], $$span2[0]);
    if ($comp) {
	# Not in the same chromosome even.
	# There's a cool way to do this with math in the indices and only one
	# return statement, but you know?  It just isn't worth it.
	if ($comp > 0) {
	    return ($span2, [], $span1);
	}
	else {
	    return ($span1, [], $span2);
	}
    }
    if ($$span1[1] > $$span2[1]) {
	# WLOG, the first span has the smaller start.  If that isn't true, swap
	($span1, $span2) = ($span2, $span1);
    }
    my @rv=();
    if ($$span1[2] < $$span2[1]) {
	push @rv, $span1, [], $span2; # No overlap, simple enough.
	return @rv;
    }
    # Otherwise...
    push @rv, [$$span1[0], $$span1[1], $$span2[1], $$span1[3]]; # pre-overlap.
    my @overlap=($$span2[0], $$span2[1], 0, $$span1[3]+$$span2[3]);
    my @post=();
    if ($$span1[2] < $$span2[2]) {
	# non-containment
	$overlap[2]=$$span1[2];
	@post=($$span1[0], $$span1[2], $$span2[2], $$span2[3]);
    }
    else {
	$overlap[2]=$$span2[2];
	@post=($$span1[0], $$span2[2], $$span1[2], $$span1[3]);
    }
    push @rv, \@overlap, \@post;
    return @rv;
}

# Eat the initial "track" line, if any.
foreach my $fh (@handles) {
    $_=<$fh>;
    seek $fh,0,0 unless /^track type=bed/;
}

# Prime the pump: read in the "next" (i.e. first) lines from each of the files.
my @nextlines=();
my @nextspans=();
foreach my $fh (@handles) {
    $_=<$fh>;
    chomp;
    push @nextlines, $_;
    my @span=split /\t/;
    push @nextspans, \@span
}
my $heap=new Heap;
# Replace the comparator
$$heap[0]=\&cmpSpanIndices;
push @$heap, $_ foreach (0..$#files);
$heap->reheap;
my $thisfile;

my $currentheap=new Heap;	# Heap of current spans.
$$currentheap[0]=\&cmpWholeSpans;

LINE: while (1) {
    # Keep a priority queue of incoming lines/spans.  Pull up the smallest
    # one, replenishing the queue (heap) with a line from whichever file
    # it came from.  Merge this "incoming" span with the "current" span,
    # if any, and output pre-overlap and overlap segments, and retain
    # post-overlap segment as "current" span.

    #%# dbg("Currentspan: ",join(",",@currentspan),"($#currentspan)\n");
    # Pick the lowest of the possible incoming spans.
    #%# dbg("nextlines: ",join("\n\t",@nextlines));
    #%# dbg("Heap: @$heap\n");
    if ($#$heap<=0) {
	while ($#$currentheap > 0) {
	    output(@{$currentheap->poplowest()});
	}
	output();		# Flush
	exit(0);
    }
    if ($#$currentheap <= 0) {
	$thisfile=$heap->poplowest();
	$currentheap->pushon($nextspans[$thisfile]);
	chomp($nextlines[$thisfile]=readline($handles[$thisfile]));
	{
	    my @span=split /\t/, $nextlines[$thisfile];
	    $nextspans[$thisfile]=\@span;
	}
	$heap->pushon($thisfile) if $nextlines[$thisfile];
    }
    $thisfile=$heap->poplowest();
    @incomingspan=@{$nextspans[$thisfile]};
    #%# dbg("Picked (@incomingspan) from index $thisfile\n");
    chomp($nextlines[$thisfile]=readline($handles[$thisfile]));
    my @span=split /\t/, $nextlines[$thisfile];
    $nextspans[$thisfile]=\@span;
    $heap->pushon($thisfile) if $nextlines[$thisfile];
    # What needs to happen is to go down the heap of currentspans,
    # and output each one that ends before the start of the incoming one.
    # as soon as we hit one that doesn't end before the start of incoming,
    # combine that with the incoming.  Then... do we output the pre-overlap?
    # Or push it into the currentheap?  Either way, push the overlap
    # and post-overlap into the currentheap.
    # Wait, but then you have to KEEP popping things off the currentheap,
    # combining them with the overlap and the post-overlap, and pushing the
    # resulting pieces (all three of them!) onto the currentheap until you
    # start seeing things coming off the currentheap that end later than
    # the end of the incoming span.
    # Obv, if you do this as written, and push things back onto the heap as
    # they're generated, you'll get into an infinite loop.  Need to save all 
    # these pieces in a list someplace and push them on afterward.
    my $thisref=$currentheap->poplowest();
    my @thisspan;
    @thisspan=@$thisref;
    while ($thisref and @thisspan and 
	   (($incomingspan[0] eq $thisspan[0] and
	     $thisspan[2] < $incomingspan[1]) or
	    calledCmpChrs($thisspan[0], $incomingspan[0]) < 0)) {
	output(@thisspan);
	$thisref=$currentheap->poplowest();
	@thisspan=@$thisref if $thisref;
    }

    if (!$thisref or !@thisspan) {
	# Um... do anything?  I think this is the "quiescent" state,
	# and we push the incoming span into the currentheap, and start
	# over.
	# need a new variable; if we use \@incomingspan it'll be THE SAME
	# as @incomingspan and get changed as @incomingspan is.  I don't
	# know the tricks and notation for references well enough, maybe.
	my @span=@incomingspan;
	$currentheap->pushon(\@span);
	next LINE;
    }

    # At this point, ready *start* the combining phase.
    # keep at this so long as the end of the thisspan (off the currentheap)
    # is less or equal to the end of the incoming span.
    my @holding=();
    my $firsttime=1;		# Output only the first time through.
    while (@thisspan and @incomingspan and
	   $thisspan[1] <= $incomingspan[2]) {

	my @newspans=combinespans(\@thisspan, \@incomingspan);
	#%# dbg("Combined: ((@{$newspans[0]}), (@{$newspans[1]}), (@{$newspans[2]}))\n");

	# Important loop invariant: at any time, the spans on the
	# currentheap do _not_ overlap with each other.  Moreover, we
	# are generating spans in the holding list which also do 
	# not overlap, to push into the currentheap.
	# Check for merging
	# Note that merging can only happen on the first time through. <- ???
	if ((!@{$newspans[1]} or
	     ${$newspans[1]}[1] == ${$newspans[1]}[2]) and
	    ${$newspans[0]}[0] eq ${$newspans[2]}[0] and
	    ${$newspans[0]}[2] == ${$newspans[2]}[1] and
	    ${$newspans[0]}[3] == ${$newspans[2]}[3]) {
	    my @span;
	    @span=(${$newspans[0]}[0],
		   ${$newspans[0]}[1],
		   ${$newspans[2]}[2],
		   ${$newspans[0]}[3]);
	    # Merging is a strange case.  You can't push it onto
	    # holding, because other stuff might interfere with it.
	    # The merged span has to be the span from currentheap
	    # *extended* by the incoming span.  This may interfere with
	    # later spans, so we have to consider this whole thing as
	    # the new incoming span. <- ???
	    @incomingspan=@span;
	}
	# Careful.  With a 2-way merge, we were guaranteed that no subsequent
	# reads would interfere with the pre-overlap region *or* the overlap
	# region.  That is not the case with an n-way merge.  We *can* be
	# certain that no subsequent reads will interfere with the pre-overlap
	# region, so we can output that (because the spans are coming in order
	# by beginning-number, so nothing else can have a smaller start
	# than this incoming span).  But there might be more reads coming in
	# on top of the overlap and post-overlap region, potentially breaking
	# those up into an arbitrary number of spans!  Oh no, is this going to
	# be possible?
	
	# Going to need another heap, this one of currentspans.
	
	# Don't work with empty or zero spans
	if (${$newspans[0]}[1] < ${$newspans[0]}[2] and
	    ${$newspans[0]}[3]) {
	    if ($firsttime) {
		output(@{$newspans[0]});
	    }
	    else {
		push @holding, $newspans[0];
	    }
	}
	$firsttime=0;
	# The overlap might be empty.
	if (@{$newspans[1]} and
	    ${$newspans[1]}[1] < ${$newspans[1]}[2] and
	    ${$newspans[1]}[3]) {
	    push @holding, $newspans[1];
	}
	# The incoming span has been split into non-overlapping pieces,
	# and the first two can't overlap anything else.  The third one
	# still might, so it replaces the incoming span (otherwise
	# we wind up counting earlier parts of it more than once.)
	if (@{$newspans[2]} and ${$newspans[2]}[2] > ${$newspans[2]}[1]) {
	    @incomingspan=@{$newspans[2]};
	}
	else {
	    # waitasec; if the third one is empty, then maybe the *overlap*
	    # ends with the end of the incoming span, in which case it is
	    # still subject to problems down the road, and so IT should
	    # become the incoming span.  It can't be the first (pre-overlap)
	    # part, though.
	    if (@{$newspans[1]} and ${$newspans[1]}[2] > ${$newspans[1]}[1]
		and ${newspans[1]}[2] == $incomingspan[2]) {
		# Uuuh... I think we need to pop off this span from where
		# we pushed it onto the holding.
		pop @holding;
		@incomingspan=@{$newspans[1]};
	    }
	    else {
		@incomingspan=();
	    }
	}
	
	# Pop off the next one.
	$thisref=$currentheap->poplowest();
	@thisspan=();
	@thisspan=@$thisref if $thisref;
    }
    # Whew, done now.  Push all the held stuff onto the currentheap.
    push @$currentheap, @holding;
    # This should never happen; the incoming span should have gotten eaten
    # up.  I think.  But if it doesn't, the Right Thing is to push it onto
    # the currentheap.  Better make sure it's a copy.
    if (@incomingspan) {
	my @span=@incomingspan;
	push @$currentheap, \@span;
    }
    $currentheap->reheap();
}

output();
exit(0);			# probably will never get here.
sub dbg {
    print @_;
}

sub output {
    # Output a span.  BUT actually buffer it, and only output it when the
    # next output request comes in that does *not* wind up merging with the
    # current one.
    use feature 'state';
    #%# printf "%s\t%d\t%d\t%d\n", @_;
    #%# return;
    state @bufspan;
    if (!@_) {
	# Empty parameter list means flush the buffer.
	printf "%s\t%d\t%d\t%d\n", @bufspan if @bufspan;
	undef @bufspan;
	return;
    }
    # Spans coming in are "full" spans: chr, beginning, end, count.
    unless (@bufspan) {
	@bufspan=@_;
	return;
    }
    # print "Outputting: (@bufspan), (@_)\n";
    # They merge IF the end of that one equals the beginning of this one
    # with the same counts and the same chromosome.
    if ($bufspan[3] == $_[3] and # count
	$bufspan[0] eq $_[0] and # chromosome
	$bufspan[2] == $_[1]) {	 # end of bufspan == beginning of @_
	# In that case, merge.
	$bufspan[2]=$_[2];	# Just move the end point.
    }
    # Other possible merge: if they start and end at the exact same place.
    elsif ($bufspan[0] eq @_[0] and # chromosome
	   $bufspan[1] == @_[1] and
	   $bufspan[2] == @_[2]) {
	# Add counts.
	$bufspan[3] += $_[3];
    }
    else {
	# Print out the bufspan
	printf "%s\t%d\t%d\t%d\n", @bufspan;
	@bufspan=@_;
    }
}

sub cmpWholeSpans($$) {
    my ($a, $b)=@_;
    my $comp=calledCmpChrs($$a[0], $$b[0]);
    return $comp if $comp;
    return $$a[1] <=> $$b[1];
}

################################

# Everything here *copied and pasted* from RUM_runner, so we use the same
# comparator function.  Obviously, by rights we need to pull this out into
# another file and import it into both.

# Except this.  I want to call cmpChrs as an ordinary function while not
# losing its speed as a sort comparator.  So, a wrapper.
sub calledCmpChrs($$) {
    local ($a, $b) = @_;
    # I don't trust cmpChrs to detect when they're *equal* properly.
    return 0 if $a eq $b;
    return &cmpChrs;
}

######################################################

package Heap;

sub new {
    # TODO: Find out why this is weird when the sentinel is 0!
    # index zero is special.  
    #Oh, we'll put the comparator function there.
    my $self=[sub { return $_[0] <=> $_[1]}];
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

#######################################################
package main;

sub cmpSpanIndices {
    # Incoming values are *numbers*, specifically *indices* into the
    # nextspans array.  Compare which is lower by chromosome and starting
    # position.
    # forgive me for using globals...
    my @spans=@nextspans[$_[0], $_[1]];
    my $comp=main::calledCmpChrs(${$spans[0]}[0], ${$spans[1]}[0]);
    if ($comp) {
	return $comp;
    }
    return ${$spans[0]}[1] <=> ${$spans[1]}[1]; # Compare starting locations.
}
