package RUM::Sort;

use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw(cmpChrs by_chromosome by_location merge_iterators);
use RUM::Common qw(roman Roman isroman arabic);
use RUM::FileIterator qw(peek_it pop_it);

=pod

=head1 NAME

RUM::Sort - Utilities for comparing chromosome names.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

  use RUM::Sort qw(cmpChrs sort_by_chromosome);

  @chromosomes = sort cmpChrs @chromosomes;
  @chromosomes = sort_by_chromosome @chromosomes;

=head1 DESCRIPTION

=head2 Subroutines

=over 4

=cut

=item cmpChrs

Comparator that compares chromosome names.

=cut
sub cmpChrs ($$) {
    my $a2_c = lc($_[1]);
    my $b2_c = lc($_[0]);
    if($a2_c eq 'finished1234') {
	return 1;
    }
    if($b2_c eq 'finished1234') {
	return -1;
    }
    if ($a2_c =~ /^\d+$/ && !($b2_c =~ /^\d+$/)) {
        return 1;
    }
    if ($b2_c =~ /^\d+$/ && !($a2_c =~ /^\d+$/)) {
        return -1;
    }
    if ($a2_c =~ /^[ivxym]+$/ && !($b2_c =~ /^[ivxym]+$/)) {
        return 1;
    }
    if ($b2_c =~ /^[ivxym]+$/ && !($a2_c =~ /^[ivxym]+$/)) {
        return -1;
    }
    if ($a2_c eq 'm' && ($b2_c eq 'y' || $b2_c eq 'x')) {
        return -1;
    }
    if ($b2_c eq 'm' && ($a2_c eq 'y' || $a2_c eq 'x')) {
        return 1;
    }
    if ($a2_c =~ /^[ivx]+$/ && $b2_c =~ /^[ivx]+$/) {
        $a2_c = "chr" . $a2_c;
        $b2_c = "chr" . $b2_c;
    }
    if ($a2_c =~ /$b2_c/) {
	return -1;
    }
    if ($b2_c =~ /$a2_c/) {
	return 1;
    }
    # dealing with roman numerals starts here
    if ($a2_c =~ /chr([ivx]+)/ && $b2_c =~ /chr([ivx]+)/) {
	$a2_c =~ /chr([ivx]+)/;
	my $a2_roman = $1;
	$b2_c =~ /chr([ivx]+)/;
	my $b2_roman = $1;
	my $a2_arabic = arabic($a2_roman);
    	my $b2_arabic = arabic($b2_roman);
	if ($a2_arabic > $b2_arabic) {
	    return -1;
	} 
	if ($a2_arabic < $b2_arabic) {
	    return 1;
	}
	if ($a2_arabic == $b2_arabic) {
            my $tempa = $a2_c;
	    my $tempb = $b2_c;
	    $tempa =~ s/chr([ivx]+)//;
	    $tempb =~ s/chr([ivx]+)//;
            my %temphash;
	    $temphash{$tempa}=1;
	    $temphash{$tempb}=1;
	    foreach my $tempkey (sort {cmpChrs($a,$b)} keys %temphash) {
		if ($tempkey eq $tempa) {
		    return 1;
		} else {
		    return -1;
		}
	    }
	}
    }
    if ($b2_c =~ /chr([ivx]+)/ && !($a2_c =~ /chr([a-z]+)/) && !($a2_c =~ /chr(\d+)/)) {
	return -1;
    }
    if ($a2_c =~ /chr([ivx]+)/ && !($b2_c =~ /chr([a-z]+)/) && !($b2_c =~ /chr(\d+)/)) {
	return 1;
    }

    if ($b2_c =~ /m$/ && $a2_c =~ /vi+/) {
	return 1;
    }
    if ($a2_c =~ /m$/ && $b2_c =~ /vi+/) {
	return -1;
    }

    # roman numerals ends here
    if ($a2_c =~ /chr(\d+)$/ && $b2_c =~ /chr.*_/) {
        return 1;
    }
    if ($b2_c =~ /chr(\d+)$/ && $a2_c =~ /chr.*_/) {
        return -1;
    }
    if ($a2_c =~ /chr([a-z])$/ && $b2_c =~ /chr.*_/) {
        return 1;
    }
    if ($b2_c =~ /chr([a-z])$/ && $a2_c =~ /chr.*_/) {
        return -1;
    }
    if ($a2_c =~ /chr(\d+)/) {
        my $numa = $1;
        if ($b2_c =~ /chr(\d+)/) {
            my $numb = $1;
            if ($numa < $numb) {
                return 1;
            }
	    if ($numa > $numb) {
                return -1;
            }
	    if ($numa == $numb) {
		my $tempa = $a2_c;
		my $tempb = $b2_c;
		$tempa =~ s/chr\d+//;
		$tempb =~ s/chr\d+//;
		my %temphash;
		$temphash{$tempa}=1;
		$temphash{$tempb}=1;
		foreach my $tempkey (sort {cmpChrs($a,$b)} keys %temphash) {
		    if ($tempkey eq $tempa) {
			return 1;
		    } else {
			return -1;
		    }
		}
	    }
        } else {
            return 1;
        }
    }
    if ($a2_c =~ /chrx(.*)/ && ($b2_c =~ /chr(y|m)$1/)) {
	return 1;
    }
    if ($b2_c =~ /chrx(.*)/ && ($a2_c =~ /chr(y|m)$1/)) {
	return -1;
    }
    if ($a2_c =~ /chry(.*)/ && ($b2_c =~ /chrm$1/)) {
	return 1;
    }
    if ($b2_c =~ /chry(.*)/ && ($a2_c =~ /chrm$1/)) {
	return -1;
    }
    if ($a2_c =~ /chr\d/ && !($b2_c =~ /chr[^\d]/)) {
	return 1;
    }
    if ($b2_c =~ /chr\d/ && !($a2_c =~ /chr[^\d]/)) {
	return -1;
    }
    if ($a2_c =~ /chr[^xy\d]/ && (($b2_c =~ /chrx/) || ($b2_c =~ /chry/))) {
        return -1;
    }
    if ($b2_c =~ /chr[^xy\d]/ && (($a2_c =~ /chrx/) || ($a2_c =~ /chry/))) {
        return 1;
    }
    if ($a2_c =~ /chr(\d+)/ && !($b2_c =~ /chr(\d+)/)) {
        return 1;
    }
    if ($b2_c =~ /chr(\d+)/ && !($a2_c =~ /chr(\d+)/)) {
        return -1;
    }
    if ($a2_c =~ /chr([a-z])/ && !($b2_c =~ /chr(\d+)/) && !($b2_c =~ /chr[a-z]+/)) {
        return 1;
    }
    if ($b2_c =~ /chr([a-z])/ && !($a2_c =~ /chr(\d+)/) && !($a2_c =~ /chr[a-z]+/)) {
        return -1;
    }
    if ($a2_c =~ /chr([a-z]+)/) {
        my $letter_a = $1;
        if ($b2_c =~ /chr([a-z]+)/) {
            my $letter_b = $1;
            if ($letter_a lt $letter_b) {
                return 1;
            }
	    if ($letter_a gt $letter_b) {
                return -1;
            }
        } else {
            return -1;
        }
    }
    my $flag_c = 0;
    while ($flag_c == 0) {
        $flag_c = 1;
        if ($a2_c =~ /^([^\d]*)(\d+)/) {
            my $stem1_c = $1;
            my $num1_c = $2;
            if ($b2_c =~ /^([^\d]*)(\d+)/) {
                my $stem2_c = $1;
                my $num2_c = $2;
                if ($stem1_c eq $stem2_c && $num1_c < $num2_c) {
                    return 1;
                }
                if ($stem1_c eq $stem2_c && $num1_c > $num2_c) {
                    return -1;
                }
                if ($stem1_c eq $stem2_c && $num1_c == $num2_c) {
                    $a2_c =~ s/^$stem1_c$num1_c//;
                    $b2_c =~ s/^$stem2_c$num2_c//;
                    $flag_c = 0;
                }
            }
        }
    }
    if ($a2_c le $b2_c) {
	return 1;
    }
    if ($b2_c le $a2_c) {
	return -1;
    }


    return 1;
}

=item by_chromosome A, B

Comparator that compares chromosome names.

=cut



*by_chromosome = *cmpChrs;


=item by_location(A, B)

Comparator that compares hashrefs by chromosome name, then span start,
then span end, then sequence number, and finally the sequence itself
(just so we have a consistent sort). . A and B must both be hashrefs
with the following fields:

=over 4

=item B<chr>

The chromosome name.

=item B<start>

The start location.

=item B<end>

The end location.

=item B<seqnum>

The sequence number, e.g. 1234 from seq1234.a.

=item B<seq>

The sequence in the record.

=back

=cut

sub by_location ($$) {
    my ($c, $d) = @_;
    ($c->{chr} ne $d->{chr} ? cmpChrs($c->{chr}, $d->{chr}) : 0) ||
        $c->{start}  <=> $d->{start} ||
        $c->{end}    <=> $d->{end} ||
        $c->{seqnum} <=> $d->{seqnum} ||
        $c->{seq}    cmp $d->{seq};
}

=item merge_iterators(CMP, OUT_FH, ITERATORS)

=item merge_iterators(OUT_FH, ITERATORS)

Merges the given ITERATORS together, printing the entries in the
iterators to OUT_FH. We assume that the ITERATORS are producing entries in sorted order.

If CMP is supplied, it must be a comparator function; otherwise
by_location will be used.

=cut

sub merge_iterators {

    my $cmp = \&by_location;
    my $outfile = shift;
    if (ref($outfile) =~ /^CODE/) {
        $cmp = $outfile;
        $outfile = shift;
    }
    my @iters = @_;

    @iters = grep { peek_it($_) } @iters;

    while (@iters) {
        
        my $argmin = 0;
        my $min = peek_it($iters[$argmin]);
        for (my $i = 1; $i < @iters; $i++) {
            
            my $rec = peek_it($iters[$i]);
            
            # If this one is smaller, set $argmin and $min
            # appropriately
            if (by_location($rec, $min) < 0) {
                $argmin = $i;
                $min = $rec;
            }
        }
        
        print $outfile "$min->{entry}\n";
        
        # Pop the iterator that we just printed a record from; this
        # way the next iteration will be looking at the next value. If
        # this iterator doesn't have a next value, then we've
        # exhausted it, so remove it from our list.
        pop_it($iters[$argmin]);        
        unless (peek_it($iters[$argmin])) {
            splice @iters, $argmin, 1;
        }
    }
}

=back

=cut
