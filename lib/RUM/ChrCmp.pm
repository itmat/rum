package RUM::ChrCmp;

use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw(cmpChrs sort_by_chromosome);

=pod

=head1 NAME

RUM::ChrCmp - Utilities for comparing chromosome names.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

  use RUM::ChrCmp qw(cmpChrs sort_by_chromosome);

  @chromosomes = sort cmpChrs @chromosomes;
  @chromosomes = sort_by_chromosome @chromosomes;

=head1 DESCRIPTION

=head2 Subroutines

=over 4

=cut

=item cmpChrs

Comparator that compares chromosome names.

=cut
sub cmpChrs {
  my $a2_c = lc($b);
  my $b2_c = lc($a);
  if($a2_c =~ /^\d+$/ && !($b2_c =~ /^\d+$/)) {
    return 1;
  }
  if($b2_c =~ /^\d+$/ && !($a2_c =~ /^\d+$/)) {
    return -1;
  }
  if($a2_c =~ /^[ivxym]+$/ && !($b2_c =~ /^[ivxym]+$/)) {
    return 1;
  }
  if($b2_c =~ /^[ivxym]+$/ && !($a2_c =~ /^[ivxym]+$/)) {
    return -1;
  }
    if($a2_c eq 'm' && ($b2_c eq 'y' || $b2_c eq 'x')) {
        return -1;
    }
    if($b2_c eq 'm' && ($a2_c eq 'y' || $a2_c eq 'x')) {
        return 1;
    }
    if($a2_c =~ /^[ivx]+$/ && $b2_c =~ /^[ivx]+$/) {
        $a2_c = "chr" . $a2_c;
        $b2_c = "chr" . $b2_c;
    }
    if($a2_c =~ /$b2_c/) {
	return -1;
    }
    if($b2_c =~ /$a2_c/) {
	return 1;
    }
    # dealing with roman numerals starts here
    if($a2_c =~ /chr([ivx]+)/ && $b2_c =~ /chr([ivx]+)/) {
	$a2_c =~ /chr([ivx]+)/;
	my $a2_roman = $1;
	$b2_c =~ /chr([ivx]+)/;
	my $b2_roman = $1;
	my $a2_arabic = arabic($a2_roman);
    	my $b2_arabic = arabic($b2_roman);
	if($a2_arabic > $b2_arabic) {
	    return -1;
	} 
	if($a2_arabic < $b2_arabic) {
	    return 1;
	}
	if($a2_arabic == $b2_arabic) {
          my $tempa = $a2_c;
	    my $tempb = $b2_c;
	    $tempa =~ s/chr([ivx]+)//;
	    $tempb =~ s/chr([ivx]+)//;
            my %temphash;
	    $temphash{$tempa}=1;
	    $temphash{$tempb}=1;
	    foreach my $tempkey (sort {cmpChrs($a,$b)} keys %temphash) {
		if($tempkey eq $tempa) {
		    return 1;
		} else {
		    return -1;
		}
	    }
	}
    }
    if($b2_c =~ /chr([ivx]+)/ && !($a2_c =~ /chr([a-z]+)/) && !($a2_c =~ /chr(\d+)/)) {
	return -1;
    }
    if($a2_c =~ /chr([ivx]+)/ && !($b2_c =~ /chr([a-z]+)/) && !($b2_c =~ /chr(\d+)/)) {
	return 1;
    }

    # roman numerals ends here
    if($a2_c =~ /chr(\d+)$/ && $b2_c =~ /chr.*_/) {
        return 1;
    }
    if($b2_c =~ /chr(\d+)$/ && $a2_c =~ /chr.*_/) {
        return -1;
    }
    if($a2_c =~ /chr([a-z])$/ && $b2_c =~ /chr.*_/) {
        return 1;
    }
    if($b2_c =~ /chr([a-z])$/ && $a2_c =~ /chr.*_/) {
        return -1;
    }
    if($a2_c =~ /chr(\d+)/) {
        my $numa = $1;
        if($b2_c =~ /chr(\d+)/) {
            my $numb = $1;
            if($numa < $numb) {return 1;}
	    if($numa > $numb) {return -1;}
	    if($numa == $numb) {
		my $tempa = $a2_c;
		my $tempb = $b2_c;
		$tempa =~ s/chr\d+//;
		$tempb =~ s/chr\d+//;
		my %temphash;
		$temphash{$tempa}=1;
		$temphash{$tempb}=1;
		foreach my $tempkey (sort {cmpChrs($a,$b)} keys %temphash) {
		    if($tempkey eq $tempa) {
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
    if($a2_c =~ /chrx(.*)/ && ($b2_c =~ /chr(y|m)$1/)) {
	return 1;
    }
    if($b2_c =~ /chrx(.*)/ && ($a2_c =~ /chr(y|m)$1/)) {
	return -1;
    }
    if($a2_c =~ /chry(.*)/ && ($b2_c =~ /chrm$1/)) {
	return 1;
    }
    if($b2_c =~ /chry(.*)/ && ($a2_c =~ /chrm$1/)) {
	return -1;
    }
    if($a2_c =~ /chr\d/ && !($b2_c =~ /chr[^\d]/)) {
	return 1;
    }
    if($b2_c =~ /chr\d/ && !($a2_c =~ /chr[^\d]/)) {
	return -1;
    }
    if($a2_c =~ /chr[^xy\d]/ && (($b2_c =~ /chrx/) || ($b2_c =~ /chry/))) {
        return -1;
    }
    if($b2_c =~ /chr[^xy\d]/ && (($a2_c =~ /chrx/) || ($a2_c =~ /chry/))) {
        return 1;
    }
    if($a2_c =~ /chr(\d+)/ && !($b2_c =~ /chr(\d+)/)) {
        return 1;
    }
    if($b2_c =~ /chr(\d+)/ && !($a2_c =~ /chr(\d+)/)) {
        return -1;
    }
    if($a2_c =~ /chr([a-z])/ && !($b2_c =~ /chr(\d+)/) && !($b2_c =~ /chr[a-z]+/)) {
        return 1;
    }
    if($b2_c =~ /chr([a-z])/ && !($a2_c =~ /chr(\d+)/) && !($a2_c =~ /chr[a-z]+/)) {
        return -1;
    }
    if($a2_c =~ /chr([a-z]+)/) {
        my $letter_a = $1;
        if($b2_c =~ /chr([a-z]+)/) {
            my $letter_b = $1;
            if($letter_a lt $letter_b) {return 1;}
	    if($letter_a gt $letter_b) {return -1;}
        } else {
            return -1;
        }
    }
    my $flag_c = 0;
    while($flag_c == 0) {
        my $flag_c = 1;
        if($a2_c =~ /^([^\d]*)(\d+)/) {
            my $stem1_c = $1;
            my $num1_c = $2;
            if($b2_c =~ /^([^\d]*)(\d+)/) {
                my $stem2_c = $1;
                my $num2_c = $2;
                if($stem1_c eq $stem2_c && $num1_c < $num2_c) {
                    return 1;
                }
                if($stem1_c eq $stem2_c && $num1_c > $num2_c) {
                    return -1;
                }
                if($stem1_c eq $stem2_c && $num1_c == $num2_c) {
                    $a2_c =~ s/^$stem1_c$num1_c//;
                    $b2_c =~ s/^$stem2_c$num2_c//;
                    $flag_c = 0;
                }
            }
        }
    }
    if($a2_c le $b2_c) {
	return 1;
    }
    if($b2_c le $a2_c) {
	return -1;
    }


    return 1;
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

=item roman(N)

Return the lower case roman numeral for N.

=cut
sub roman($) {
  lc Roman shift;
}

=item sort_by_chromosome()

Sort the given list by chromosome.

=cut
sub sort_by_chromosome {
  return sort cmpChrs @_;
}
