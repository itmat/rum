package RUM::Common;

use strict;
use warnings;
use autodie;

use RUM::Logging;

our $log = RUM::Logging->get_logger;

use Carp;
use Exporter qw(import);
our @EXPORT_OK = qw(getave addJunctionsToSeq roman Roman isroman arabic
                    reversecomplement format_large_int spansTotalLength
                    reversesignal read_chunk_id_mapping is_fasta is_fastq head
                    num_digits shell make_paths is_on_cluster
                    min_match_length open_r);

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
	my $len_j = ($c_j[1]||0) - ($c_j[0]||0) + 1;
	if($seq_out =~ /\S/) { # to avoid putting a colon at the beginning
	    $seq_out = $seq_out . ":";
	}
	for(my $k_j=0; $k_j<$len_j; $k_j++) {
	    if(defined($s_j[$place]) && $s_j[$place] eq "+") {
		$seq_out = $seq_out . ($s_j[$place]||"");
		$place++;
		until(defined($s_j[$place]) && $s_j[$place] eq "+") {
		    $seq_out = $seq_out . ($s_j[$place]||"");
		    $place++;
		    if($place > @s_j-1) {
			last;
		    }
		}
		$k_j--;
	    }
	    $seq_out = $seq_out . ($s_j[$place]||"");
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
    shift if (($_[0] || '') eq __PACKAGE__);
    my ($int) = @_;
    $int = '' if ! defined $int;
    my @a = split //, $int;
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

=item spansTotalLength(SPANS)

Return the total length of a list of spans. Spans should be delimited
by ", ", and each span should be start-end.

=cut

sub spansTotalLength {
    my ($spans) = @_;
    my @spans = split(/, /, $spans);
    my $length = 0;
    for my $span (@spans) {
	my ($start, $end) = split(/-/, $span);

        # TODO: What should we do if this is called with a half open
        # span like "-10" or "10-"? Originally it would just
        # implicitly use 0 for the part of the span that wasn't
        # specified. I just added 0 as the default to get rid of
        # warnings about "" not being numeric. Perhaps we should treat
        # that span as a 0-length span instead.
        $start ||= 0;
        $end   ||= 0;

	$length = $length + $end - $start + 1;
    }
    return $length;
}

=item reversesignal(SIGNAL)

Return the reverse complement of a two-character string.

  reversesignal("AC") -> "GT"

=cut

sub reversesignal {
    my ($it) = @_;
    $it =~ /(.)(.)/;
    my @base_r = ($1, $2);

    my $return_string = "";
    for(my $rr=0; $rr<2; $rr++) {
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

=item read_chunk_id_mapping($filename)

If $filename is defined and exists, reads a chunk id mapping from it
and returns it as a hash, otherwise returns undef.

=cut

sub read_chunk_id_mapping {
    my ($chunk_ids_file) = @_;
    my %chunk_ids_mapping;
    return unless $chunk_ids_file && -e $chunk_ids_file;

    open my $infile, "$chunk_ids_file"
        or die "Error: cannot open '$chunk_ids_file' for reading.\n\n";
    while (defined(local $_ = <$infile>)) {
        chomp;
        my ($old, $new) = split /\t/;
        $chunk_ids_mapping{$old} = $new unless $old eq 'chr_name';
    }
    return %chunk_ids_mapping;
}

=item head($filehandle, $n)

Return the first $n lines from the given $filehandle as a list. If
$filehandle is a string rather than a GLOB, I will attempt to open it.

=cut

sub head {
    my ($filename, $lines) = @_;

    my $fh = open_r($filename);

    my @lines;
    for (1 .. $lines) {
        defined(my $line = <$fh>) or last;
        chomp $line;
        push @lines, $line;
    }
    return @lines;
}

=item is_fastq($fh)

Returns true if the given filehandle appears to contain fastq data,
false otherwise.

=cut

sub is_fastq {
    shift if $_[0] eq __PACKAGE__;
    my ($filename) = @_;

    my @lines = head($filename, 40);

    for my $i (0 .. $#lines / 4) {
        $lines[$i*4]   =~ /^@/               or return 0;
        $lines[$i*4+1] =~ /^[acgtnACGTN.]+$/ or return 0;
        $lines[$i*4+2] =~ /^\+/              or return 0;
    }

    return 1;
}

=item is_fasta

Returns true if the given filehandle appears to contain fasta data,
false otherwise.

=cut

sub is_fasta {
    shift if $_[0] eq __PACKAGE__;
    my ($filename) = @_;

    my @lines = head($filename, 40);
    for my $i (1 .. $#lines / 2) {
        $lines[$i*2]   =~ /^>/               or return 0;
        $lines[$i*2+1] =~ /^[acgtnACGTN.]+$/ or return 0;
    }    
    return 1;
}

=item num_digits($n)

Return the number of digits in the given integer argument.

=cut

sub num_digits {
    my ($n) = (@_);
    my $size = 0;

    do {
        $size++;
        $n = int($n / 10);
    } while ($n);
    return $size;
}

=item report ARGS

Print ARGS as a message prefixed with a "#" character.

=cut

sub report {
    my @args = @_;
    print "# @args\n";
}


=item shell CMD, ARGS

Execute "$CMD @ARGS" using system unless $DRY_RUN is set. Check the
output status and croak if it fails.

=cut

sub shell {
    my @cmd = @_;
    $log->info("Running @cmd");
    system(@cmd) == 0 or croak "Error running @cmd";
}

=item is_on_cluster

Return true if I appear to be running on the cluster.

=cut

sub is_on_cluster {
    return is_executable_in_path("qsub");
}

=item is_executable_in_path BIN_NAME

Return true if the given filename is in the path and is executable.

=cut

sub is_executable_in_path {
    my ($bin_name) = @_;
    local $_ = `which $bin_name`;
    chomp;
    return undef unless $_;
    return -x;
}

=item min_match_length($read_length)

Return the minimum-length match we will allow for a read of the given
length.

=cut

sub min_match_length {
    my ($read_length) = @_;
    my $result;
    if ($read_length < 80) {
        $result ||= 35;
    } else {
        $result ||= 50;
    }
    if($result >= .8 * $read_length) {
        $result = int(.6 * $read_length);
    }
    return $result;
}

=item is_gz($filename)

Return true if $filename is a gzip-compressed file, false otherwise.

=item open_r($filename)

Return a read-only filehandle for the given filename. If the filename
ends with .gz, the filehandle will unzip it and return a stream of
uncompressed data.

=cut

sub open_r {
    my ($filename) = @_;
    my $mode = '<';
    if ($filename =~ /\.gz$/) {
        die "I'm sorry, I don't support gzipped input at this time.  We plan on adding support for this in the near future.  In the meantime, please unzip your input files with 'gunzip' before running RUM.\n";
        $filename = "gunzip -c $filename";
        $mode = "-|";
    }
    my $in;
    open $in, $mode, $filename;
    return $in;
}



1;
