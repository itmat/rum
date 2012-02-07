package RUM::Common;

use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(getave addJunctionsToSeq);

=head1 FUNCTIONS

=over 4

=item getave

TODO: Document me

=cut 

sub getave {
    my ($spans_x) = @_;

    my @spans = split(/, /, $spans_x);
    my $ave = 0;
    my $len = 0;
    for my $span (@spans) {
	my ($start, $end) = split(/-/, $span);
	$ave = $ave + $end*($end+1)/2 - $start*($start-1)/2;
	$len = $len + $end - $start + 1;
    }
    $ave = $ave / $len;

    return $ave;
}

sub addJunctionsToSeq {
    my ($seq, $spans) = @_;
    $seq =~ s/://g;
    my @s_j = split(//,$seq);
    my @b_j = split(/, /,$spans);
    my $seq_out = "";
    my $place = 0;
    for(my $j_j=0; $j_j<@b_j; $j_j++) {
	my @c_j = split(/-/,$b_j[$j_j]);
	my $len_j = $c_j[1] - $c_j[0] + 1;
	if($seq_out =~ /\S/) { # to avoid putting a colon at the beginning
	    $seq_out = $seq_out . ":";
	}
	for(my $k_j=0; $k_j<$len_j; $k_j++) {
	    if($s_j[$place] eq "+") {
		$seq_out = $seq_out . $s_j[$place];
		$place++;
		until($s_j[$place] eq "+") {
		    $seq_out = $seq_out . $s_j[$place];
		    $place++;
		    if($place > @s_j-1) {
			last;
		    }
		}
		$k_j--;
	    }
	    $seq_out = $seq_out . $s_j[$place];
	    $place++;
	}
    }
    return $seq_out;
}



1;
