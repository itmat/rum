package RUM::Common;

use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(getave addJunctionsToSeq roman Roman isroman arabic
                    reversecomplement format_large_int spansTotalLength
                    reversesignal);

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

=item addJunctionsToSeq

TODO: Document me

=cut

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

=item roman(N)

Return the lower case roman numeral for N.

=cut
sub roman($) {
    return lc(Roman(shift()));
}

=item isroman(N)

Return a true value if N is a roman numeral, false otherwise.

=cut
sub isroman($) {
    my $arg = shift;
    return $arg ne '' and
        $arg =~ /^(?: M{0,3})
                 (?: D?C{0,3} | C[DM])
                 (?: L?X{0,3} | X[LC])
                 (?: V?I{0,3} | I[VX])$/ix;
}

=item arabic(N)

Return the arabic number for the given roman numeral.

=cut
sub arabic($) {
    my $arg = shift;
    my %roman2arabic = qw(I 1 V 5 X 10 L 50 C 100 D 500 M 1000);
    my %roman_digit = qw(1 IV 10 XL 100 CD 1000 MMMMMM);
    my  @figure = reverse sort keys %roman_digit;
    $roman_digit{$_} = [split(//, $roman_digit{$_}, 2)] foreach @figure;
    isroman $arg or return undef;
    my ($last_digit) = 1000;
    my $arabic=0;
    foreach (split(//, uc $arg)) {
        my ($digit) = $roman2arabic{$_};
        $arabic -= 2 * $last_digit if $last_digit < $digit;
        $arabic += ($last_digit = $digit);
    }
    $arabic;
}

=item Roman(N)

Return the roman numeral for N.

=cut
sub Roman($) {
    my $arg = shift;
    my %roman2arabic = qw(I 1 V 5 X 10 L 50 C 100 D 500 M 1000);
    my %roman_digit = qw(1 IV 10 XL 100 CD 1000 MMMMMM);
    my @figure = reverse sort keys %roman_digit;
    $roman_digit{$_} = [split(//, $roman_digit{$_}, 2)] foreach @figure;
    0 < $arg and $arg < 4000 or return undef;
    my $roman = "";
    my $x;
    foreach (@figure) {
        my ($digit, $i, $v) = (int($arg / $_), @{$roman_digit{$_}});
        if (1 <= $digit and $digit <= 3) {
            $roman .= $i x $digit;
        } elsif ($digit == 4) {
            $roman .= "$i$v";
        } elsif ($digit == 5) {
            $roman .= $v;
        } elsif (6 <= $digit and $digit <= 8) {
            $roman .= $v . $i x ($digit - 5);
        } elsif ($digit == 9) {
            $roman .= "$i$x";
        }
        $arg -= $digit * $_;
        $x = $i;
    }
    $roman;
}

=item reversecomplement SEQUENCE

Return the reverse complement of SEQUENCE.

=cut

sub reversecomplement {

  my ($sq) = @_;
  my @A = split(//,$sq);
  my $rev = "";
  my $flag;
  for (my $i=@A-1; $i>=0; $i--) {
    $flag = 0;
    if($A[$i] eq 'A') {
      $rev = $rev . "T";
      $flag = 1;
    }
    if($A[$i] eq 'T') {
      $rev = $rev . "A";
      $flag = 1;
    }
    if($A[$i] eq 'C') {
      $rev = $rev . "G";
      $flag = 1;
    }
    if($A[$i] eq 'G') {
      $rev = $rev . "C";
      $flag = 1;
    }
    if($flag == 0) {
      $rev = $rev . $A[$i];
    }
  }
  return $rev;
}

=item format_large_int X

Return X formatted with commas between every triplet of digits.

=cut

sub format_large_int {
    my ($int) = @_;
    my @a = split(//,"$int");
    my $j = 0;
    my $newint = "";
    my $n = @a;
    for (my $i = $n - 1; $i >=0; $i--) {
	$j++;
	$newint = $a[$i] . $newint;
	if($j % 3 == 0) {
	    $newint = "," . $newint;
	}
    }
    $newint =~ s/^,//;
    return $newint;
}

sub spansTotalLength {
    my ($spans) = @_;
    my @a = split(/, /,$spans);
    my $length = 0;
    for($i=0; $i<@a; $i++) {
	my @b = split(/-/,$a[$i]);
	$length = $length + $b[1] - $b[0] + 1;
    }
    return $length;
}

sub reversesignal {
    my ($it) = @_;
    $it =~ /(.)(.)/;
    my @base_r = ($1, $2);

    my $return_string = "";
    for($rr=0; $rr<2; $rr++) {
	if($base_r[$rr] eq "A") {
	    $return_string = "T" . $return_string;
	}
	if($base_r[$rr] eq "T") {
	    $return_string = "A" . $return_string;
	}
	if($base_r[$rr] eq "C") {
	    $return_string = "G" . $return_string;
	}
	if($base_r[$rr] eq "G") {
	    $return_string = "C" . $return_string;
	}
    }
    return $return_string;
}




1;
