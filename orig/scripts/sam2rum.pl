#!/usr/bin/perl

# Written by Gregory R. Grant
# University of Pennsylvania, 2010

if(@ARGV < 1) {
    die "
Usage: sam2rum.pl <sam file> <RUM Unique outfile> <RUM NU outfile> [options]

Outputs to RUM format:

seq_name   chr    spans    sequence

Where sequence has a colon to indicate gaps and +XXX+ to indicates an insertion of XXX

If you want the unique and non-unique mappers all in one file, put 'none' for the
<RUM NU outfile> argument and everything will be written to the first file even if
not unique.

Options:
           -uniqueRecords : There is only one record for each sequence.
           -noHtag  :  There aren't HI and IH tag indicating the number of alignments.
                       In this case I will figure out the number the hard way...

";
}

$noHtag = "false";
$unique_records = "false";
for($i=3; $i<@ARGV; $i++) {
    $optionrecognized = 0;
    if($ARGV[$i] eq "-noHtag") {
	$noHtag = "true";
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-uniqueRecords") {
	$unique_records = "true";
	$optionrecognized = 1;
    }
    if($optionrecognized == 0) {
	die "\nERROR: option '$ARGV[$i]' not recognized\n";
    }
}

if($noHtag eq "true") {
    open(INFILE, $ARGV[0]) or die "\nError: Cannot open '$ARGV[0]' for reading\n\n";
    while($line = <INFILE>) {
	$line =~ /^seq.(\d+.)/;
	$sname = $1;
	@a = split(/\t/,$line);
	if(!($a[2] eq "*")) {
	    $number_occurrences{$sname}++;
	}
    }
}
close(INFILE);

# need 0, 2, 3, 4, 5, 6, 7 to be correct or this script won't work


$bitflag[0] = "the read is paired in sequencing";
$bitflag[1] = "the read is mapped in a proper pair";
$bitflag[2] = "the query sequence itself is unmapped";
$bitflag[3] = "the mate is unmapped";
$bitflag[4] = "strand of the query";
$bitflag[5] = "strand of the mate";
$bitflag[6] = "the read is the first read in a pair";
$bitflag[7] = "the read is the second read in a pair";
$bitflag[8] = "the alignment is not primary";
$bitflag[9] = "the read fails platform/vendor quality checks";
$bitflag[10] = "the read is either a PCR duplicate or an optical duplicate";

$|=1;

open(INFILE, $ARGV[0]) or die "\nError: Cannot open '$ARGV[0]' for reading\n\n";
$line = <INFILE>;
while($line =~ /^@/) {
    $line = <INFILE>;
}
$rum_u_outfile = $ARGV[1];
open(UOUT, ">$rum_u_outfile") or die "\nError: Cannot open '$ARGV[1]' for writing\n\n";;
$rum_nu_outfile = $ARGV[2];
$nu_separate = "true";
if($ARGV[2] =~ /none/ || $ARGV[2] =~ /.none./) {
    $nu_separate = "false";
} else {
    open(NUOUT, ">$rum_nu_outfile") or die "\nError: Cannot open '$ARGV[2]' for writing\n\n";;
}

until($line eq '') {
    chomp($line);
    @a = split(/\t/,$line);
    if($line =~ /OL:A:T/) {
	$joined = "true";
    } else {
	$joined = "false";
    }
    if($line =~ /IH:i:(\d+)/) {
	$number_of_alignments = $1;
    } elsif($line =~ /NH:i:(\d+)/) {
	$number_of_alignments = $1;
    } elsif ($unique_records eq "true") {
	$number_of_alignments = 1;	
    } elsif ($noHtag eq "true") {
	$seqname = $a[0];
	$seqname =~ s/seq.//;
	if($number_occurrences{$seqname} > 1) {
	    $number_of_alignments = 2; # just need it to be anything bigger than 1
	} else {
	    $number_of_alignments = $number_occurrences{$seqname};
	}
    } else {
	$number_of_alignments = 0;
    }

    $seq = $a[9];
    $bitstring = $a[1];
    for($j=0; $j<10; $j++) {
	if($bitstring & 2**$j) {
	    $BIT[$j] = 1;
	} else {
	    $BIT[$j] = 0;
	}
    }
    if($BIT[6] + $BIT[7] == 0) {
	$paired = "false";
    } else {
	$paired = "true";
    }
    $spans = "";
    $matchstring = $a[5];
    $a[2] =~ s/:.*//;
    $chr = $a[2];
    $seqname = $a[0];
    $start = $a[3];
    $current_loc = $start;
    $offset = 0;
    while($matchstring =~ /^(\d+)([^\d])/) {
	$num = $1;
	$type = $2;
	if($type eq 'M') {
	    $E = $current_loc + $num - 1;
	    if($spans =~ /\S/) {
		$spans = $spans . ", " .  $current_loc . "-" . $E;
	    } else {
		$spans = $current_loc . "-" . $E;
	    }
	    $offset = $offset + $num;
	    $current_loc = $E;
	}
	if($type eq 'D' || $type eq 'N') {
	    $current_loc = $current_loc + $num + 1;
	}
	if($type eq 'S') {
	    if($matchstring =~ /^\d+S\d/) {
		for($i=0; $i<$num; $i++) {
		    $seq =~ s/^.//;
		}
	    } elsif($matchstring =~ /\d+S$/) {
		for($i=0; $i<$num; $i++) {
		    $seq =~ s/.$//;
		}
	    }
	}
	if($type eq 'I') {
	    $current_loc++;
	    substr($seq, $offset, 0, "+");
	    $offset = $offset  + $num + 1;
	    substr($seq, $offset, 0, "+");
	    $offset = $offset + 1;
	}
	$matchstring =~ s/^\d+[^\d]//;
    }
    $spans2 = "";
    while($spans2 ne $spans) {
	$spans2 = $spans;
	@b = split(/, /, $spans);
	for($i=0; $i<@b-1; $i++) {
	    @c1 = split(/-/, $b[$i]);
	    @c2 = split(/-/, $b[$i+1]);
	    if($c1[1] + 1 >= $c2[0]) {
		$str = "-$c1[1], $c2[0]";
		$spans =~ s/$str//;
	    }
	}
    }

    if($BIT[4] == 0 && ($BIT[6] == 1 || $BIT[0] == 0)) {
	$strand = "+";
    }
    if($BIT[4] == 1 && ($BIT[6] == 1 || $BIT[0] == 0)) {
	$strand = "-";
    }
    if($BIT[3] == 1 && $BIT[7] == 1) {
	if($BIT[4] == 0) {
	    $strand = "-";
	} else {
	    $strand = "+";
	}
    }    
    if($paired eq "false") {
	$seq_with_junctions = addJunctionsToSeq($seq, $spans);
	if($number_of_alignments == 1) {
	    print UOUT "$seqname\t$chr\t$spans\t$strand\t$seq_with_junctions\n";
	} else {
	    print NUOUT "$seqname\t$chr\t$spans\t$strand\t$seq_with_junctions\n";
	}
    } else {
	if($BIT[6] == 1) {
	    $forward_seqname = $seqname;
	    $forward_chr = $chr;
	    $forward_spans = $spans;
	    $forward_seq = $seq;
	}
	if($BIT[7] == 1) {
	    $reverse_seqname = $seqname;
	    $reverse_chr = $chr;
	    $reverse_spans = $spans;
	    $reverse_seq = $seq;
	    $reverse_spans =~ /^(\d+)-/;
	    $reverse_start = $1;
	    $reverse_spans =~ /-(\d+)$/;
	    $reverse_end = $1;
	    $forward_spans =~ /^(\d+)-/;
	    $forward_start = $1;
	    $forward_spans =~ /-(\d+)$/;
	    $forward_end = $1;
	    if($strand eq "+") {
		if(!($forward_spans =~ /\S/) && $reverse_spans =~ /\S/) {
		    $reverse_seq_with_junctions = addJunctionsToSeq($reverse_seq, $reverse_spans);
		    if($reverse_seqname =~ /\S/) {
			if($number_of_alignments == 1) {
			    print UOUT "$reverse_seqname\t$reverse_chr\t$reverse_spans\t$strand\t$reverse_seq_with_junctions\n";
			} else {
			    print NUOUT "$reverse_seqname\t$reverse_chr\t$reverse_spans\t$strand\t$reverse_seq_with_junctions\n";
			}
		    }
		} elsif($forward_spans =~ /\S/ && !($reverse_spans =~ /\S/)) {
		    $forward_seq_with_junctions = addJunctionsToSeq($forward_seq, $forward_spans);
		    if($forward_seqname =~ /\S/) {
			if($number_of_alignments == 1) {
			    print UOUT "$forward_seqname\t$forward_chr\t$forward_spans\t$strand\t$forward_seq_with_junctions\n";
			} else {
			    print NUOUT "$forward_seqname\t$forward_chr\t$forward_spans\t$strand\t$forward_seq_with_junctions\n";
			}
		    }
		} elsif($forward_end + 1 < $reverse_start || $forward_chr ne $reverse_chr) {
		    $forward_seq_with_junctions = addJunctionsToSeq($forward_seq, $forward_spans);
		    $reverse_seq_with_junctions = addJunctionsToSeq($reverse_seq, $reverse_spans);
		    if($joined eq "false") {
			if($forward_seqname =~ /\S/) {
			    if($number_of_alignments == 1) {
				print UOUT "$forward_seqname\t$forward_chr\t$forward_spans\t$strand\t$forward_seq_with_junctions\n";
			    } else {
				print NUOUT "$forward_seqname\t$forward_chr\t$forward_spans\t$strand\t$forward_seq_with_junctions\n";
			    }
			}
			if($reverse_seqname =~ /\S/) {
			    if($number_of_alignments == 1) {
				print UOUT "$reverse_seqname\t$reverse_chr\t$reverse_spans\t$strand\t$reverse_seq_with_junctions\n";
			    } else {
				print NUOUT "$reverse_seqname\t$reverse_chr\t$reverse_spans\t$strand\t$reverse_seq_with_junctions\n";
			    }
			}
		    } else {
			$Sname = $forward_seqname;
			$Sname =~ s/a//;
			if($number_of_alignments == 1) {
			    print UOUT "$Sname\t$forward_chr\t$forward_spans, $reverse_spans\t$strand\t$forward_seq_with_junctions:$reverse_seq_with_junctions\n";
			} else {
			    print NUOUT "$Sname\t$forward_chr\t$forward_spans, $reverse_spans\t$strand\t$forward_seq_with_junctions:$reverse_seq_with_junctions\n";
			}
		    }
		} elsif($forward_spans =~ /\S/ && $reverse_spans =~ /\S/) {
		    ($merged_spans, $merged_seq) = merge($forward_spans, $reverse_spans, $forward_seq, $reverse_seq);
		    $forward_seqname =~ s/a//;
		    $seq_with_junctions = addJunctionsToSeq($merged_seq, $merged_spans);
		    if($number_of_alignments == 1) {
			print UOUT "$forward_seqname\t$forward_chr\t$merged_spans\t$strand\t$seq_with_junctions\n";
		    } else {
			print NUOUT "$forward_seqname\t$forward_chr\t$merged_spans\t$strand\t$seq_with_junctions\n";
		    }
		}
	    }

	    if($strand eq "-") {
		if(!($forward_spans =~ /\S/) && $reverse_spans =~ /\S/) {
		    $reverse_seq_with_junctions = addJunctionsToSeq($reverse_seq, $reverse_spans);
		    if($reverse_seqname =~ /\S/) {
			if($number_of_alignments == 1) {
			    print UOUT "$reverse_seqname\t$reverse_chr\t$reverse_spans\t$strand\t$reverse_seq_with_junctions\n";
			} else {
			    print NUOUT "$reverse_seqname\t$reverse_chr\t$reverse_spans\t$strand\t$reverse_seq_with_junctions\n";
			}
		    }
		} elsif($forward_spans =~ /\S/ && !($reverse_spans =~ /\S/)) {
		    $forward_seq_with_junctions = addJunctionsToSeq($forward_seq, $forward_spans);
		    if($forward_seqname =~ /\S/) {
			if($number_of_alignments == 1) {
			    print UOUT "$forward_seqname\t$forward_chr\t$forward_spans\t$strand\t$forward_seq_with_junctions\n";
			} else {
			    print NUOUT "$forward_seqname\t$forward_chr\t$forward_spans\t$strand\t$forward_seq_with_junctions\n";
			}
		    }
		} elsif($reverse_end + 1 < $forward_start || $forward_chr ne $reverse_chr) {
		    $forward_seq_with_junctions = addJunctionsToSeq($forward_seq, $forward_spans);
		    $reverse_seq_with_junctions = addJunctionsToSeq($reverse_seq, $reverse_spans);
		    if($joined eq "false") {
			if($forward_seqname =~ /\S/) {
			    if($number_of_alignments == 1) {
				print UOUT "$forward_seqname\t$forward_chr\t$forward_spans\t$strand\t$forward_seq_with_junctions\n";
			    } else {
				print NUOUT "$forward_seqname\t$forward_chr\t$forward_spans\t$strand\t$forward_seq_with_junctions\n";
			    }
			}
			if($reverse_seqname =~ /\S/) {
			    if($number_of_alignments == 1) {
				print UOUT "$reverse_seqname\t$reverse_chr\t$reverse_spans\t$strand\t$reverse_seq_with_junctions\n";
			    } else {
				print NUOUT "$reverse_seqname\t$reverse_chr\t$reverse_spans\t$strand\t$reverse_seq_with_junctions\n";			    }
			}
		    } else {
			$Sname = $forward_seqname;
			$Sname =~ s/a//;
			if($number_of_alignments == 1) {
			    print UOUT "$Sname\t$forward_chr\t$reverse_spans, $forward_spans\t$strand\t$reverse_seq_with_junctions:$forward_seq_with_junctions\n";
			} else {
			    print NUOUT "$Sname\t$forward_chr\t$reverse_spans, $forward_spans\t$strand\t$reverse_seq_with_junctions:$forward_seq_with_junctions\n";
			}
		    }
		} elsif($forward_spans =~ /\S/ && $reverse_spans =~ /\S/) {
		    ($merged_spans, $merged_seq) = merge($reverse_spans, $forward_spans, $reverse_seq, $forward_seq);
		    $forward_seqname =~ s/a//;
		    $seq_with_junctions = addJunctionsToSeq($merged_seq, $merged_spans);
		    if($number_of_alignments == 1) {
			print UOUT "$forward_seqname\t$forward_chr\t$merged_spans\t$strand\t$seq_with_junctions\n";
		    } else {
			print NUOUT "$forward_seqname\t$forward_chr\t$merged_spans\t$strand\t$seq_with_junctions\n";
		    }
		}
	    }

	    $forward_seqname = "";
	    $forward_chr = "";
	    $forward_spans = "";
	    $forward_seq = "";
	}
    }
# DEBUG
#	for($j=0; $j<10; $j++) {
#	    print "$bitflag[$j]\t$BIT[$j]\n";
#        }
# DEBUG

    $line = <INFILE>;
}

sub merge () {
    ($fspans, $rspans, $seq1, $seq2) = @_;

    undef %HASH;
    undef @Farray;
    undef @Rarray;
    undef @Fspans;
    undef @Rspans;
    undef @Fstarts;
    undef @Rstarts;
    undef @Fends;
    undef @Rends;
    undef @T;

    @Fspans = split(/, /,$fspans);
    @Rspans = split(/, /,$rspans);
    $num_F = @Fspans;
    $num_R = @Rspans;
    for($i1=0; $i1<$num_F; $i1++) {
	@T = split(/-/, $Fspans[$i1]);
	$Fstarts[$i1] = $T[0];
	$Fends[$i1] = $T[1];
    }
    for($i1=0; $i1<$num_R; $i1++) {
	@T = split(/-/, $Rspans[$i1]);
	$Rstarts[$i1] = $T[0];
	$Rends[$i1] = $T[1];
    }

    if($num_F > 1 && ($Fends[$num_F-1]-$Fstarts[$num_F-1]) <= 5) {
	if($Fstarts[0] <= $Rstarts[0] && $Rends[$num_R-1] < $Fends[$num_F-1]) {
	    $fspans =~ s/, (\d+)-(\d+)$//;
	    $length_diff = $2 - $1 + 1;
	    for($i1=0; $i1<$length_diff; $i1++) {
		$seq1 =~ s/.$//;
	    }
	    ($merged, $merged_seq) = merge($fspans, $rspans, $seq1, $seq2);
	    if(!($merged =~ /\S/)) {
		($merged, $merged_seq) = merge($rspans, $fspans, $seq2, $seq1);		
	    }
	    return ($merged, $merged_seq);
	}
    }
    if($num_F > 1 && ($Fends[0]-$Fstarts[0]) <= 5) {
	if($Rstarts[0] < $Fstarts[0] && $Rends[$num_R-1] >= $Fends[$num_F-1]) {
	    $rspans =~ s/^(\d+)-(\d+), //;
	    $length_diff = $2 - $1 + 1;
	    for($i1=0; $i1<$length_diff; $i1++) {
		$seq2 =~ s/^.//;
	    }
	    ($merged, $merged_seq) = merge($fspans, $rspans, $seq1, $seq2);
	    if(!($merged =~ /\S/)) {
		($merged, $merged_seq) = merge($rspans, $fspans, $seq2, $seq1);		
	    }
	    return ($merged, $merged_seq);
	}
    }

    if($Fends[$num_F-1] == $Rstarts[0]-1) {
	$fspans =~ s/-\d+$//;
	$rspans =~ s/^\d+-//;
	$seq = $seq1 . $seq2;
	$merged = $fspans . "-" . $rspans;
	return ($merged, $seq);
    }
    if($Fends[$num_F-1] < $Rstarts[0]-1) {
	$seq = $seq1 . $seq2;
	$merged = $fspans . ", " . $rspans;
	return ($merged, $seq);
    }
    # the following makes an array of alternating starts and ends for the forward read
    for($i1=0; $i1<$num_F; $i1++) {
	$Farray[2*$i1] = $Fstarts[$i1];
	$Farray[2*$i1+1] = $Fends[$i1];
    }
    # and for the reverse read
    for($i1=0; $i1<$num_R; $i1++) {
	$Rarray[2*$i1] = $Rstarts[$i1];
	$Rarray[2*$i1+1] = $Rends[$i1];
    }
    $Flength = 0;
    $Rlength = 0;
    for($i1=0; $i1<@Farray; $i1=$i1+2) {
	$Flength = $Flength + $Farray[$i1+1] - $Farray[$i1] + 1;
    }
    for($i1=0; $i1<@Rarray; $i1=$i1+2) {
	$Rlength = $Rlength + $Rarray[$i1+1] - $Rarray[$i1] + 1;
    }
    # the following finds the first forward segment which overlaps the first reverse segment
    $i1=0;
    $flag1 = 0;
    until($i1>=@Farray || ($Farray[$i1] <= $Rarray[0] && $Rarray[0] <= $Farray[$i1+1])) {
	$i1 = $i1+2;
    } 
    if($i1>=@Farray) {
	$flag1 = 1;
    }
    $Fhold = $Farray[$i1];
    for($j1=$i1+1; $j1<@Farray-1; $j1++) {
	if($Farray[$j1] != $Rarray[$j1-$i1]) {
	    $flag1 = 1;
	} 
    }
    $Rhold = $Rarray[@Farray-1-$i1];
    if(!($Farray[@Farray-1] >= $Rarray[@Farray-$i1-2] && $Farray[@Farray-1] <= $Rarray[@Farray-$i1-1])) {
	$flag1 = 1;
    }
    $merged="";
    $Rarray[0] = $Fhold;
    $Farray[@Farray-1] = $Rhold;
    if($flag1 == 0) {
	for($i1=0; $i1<@Farray-1; $i1=$i1+2) {
	    $HASH{"$Farray[$i1]-$Farray[$i1+1]"}++;
	}
	for($i1=0; $i1<@Rarray-1; $i1=$i1+2) {
	    $HASH{"$Rarray[$i1]-$Rarray[$i1+1]"}++;
	}
	$merged_length=0;
	foreach $key (sort {$a<=>$b} keys %HASH) {
	    $merged = $merged . ", $key";
	    @A = split(/-/,$key);
	    $merged_length = $merged_length + $A[1] - $A[0] + 1;
	}
	$suffix_length = $merged_length - $Flength;
	$offset = $Rlength - $suffix_length;
	$suffix = "";
	for($i1=0; $i1<$suffix_length; $i1++) {
	    $seq2 =~ s/(.)$//;
	    $base = $1;
	    if($base ne "+") {
		$suffix = $base . $suffix;
	    } else {
		$suffix = "+" . $suffix;
		$seq2 =~ s/(.)$//;
		$base = $1;		
		until($base eq "+") {
		    $suffix = $base . $suffix;
		    $seq2 =~ s/(.)$//;
		    $base = $1;		
		}
		$suffix = "+" . $suffix;
		$i1--;
	    }
	}
	$seq2 =~ s/(.)$//;
	$base = $1;
	if($base eq "+") {
	    $suffix = "+" . $suffix;
	    $seq2 =~ s/(.)$//;
	    $base = $1;		
	    until($base eq "+") {
		$suffix = $base . $suffix;
		$seq2 =~ s/(.)$//;
		$base = $1;		
	    }
	    $suffix = "+" . $suffix;
	}
	$merged =~ s/\s*,\s*$//;
	$merged =~ s/^\s*,\s*//;
	$merged_seq = $seq1 . $suffix;
	return ($merged, $merged_seq);
    }
}

sub addJunctionsToSeq () {
    ($seq, $spans) = @_;
    $seq =~ s/://g;
    @s = split(//,$seq);
    @b = split(/, /,$spans);
    $seq_out = "";
    $place = 0;
    for($j=0; $j<@b; $j++) {
	@c = split(/-/,$b[$j]);
	$len = $c[1] - $c[0] + 1;
	if($seq_out =~ /\S/) { # to avoid putting a colon at the beginning
	    $seq_out = $seq_out . ":";
	}
	for($k=0; $k<$len; $k++) {
	    if($s[$place] eq "+") {
		$seq_out = $seq_out . $s[$place];
		$place++;
		until($s[$place] eq "+") {
		    $seq_out = $seq_out . $s[$place];
		    $place++;
		    if($place > @s-1) {
			last;
		    }
		}
		$k--;
	    }
	    $seq_out = $seq_out . $s[$place];
	    $place++;
	}
    }
    return $seq_out;
}
