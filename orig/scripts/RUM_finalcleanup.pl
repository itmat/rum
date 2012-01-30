#!/usr/bin/perl

# Written by Gregory R. Grant
# University of Pennsylvania, 2010

$|=1;

if(@ARGV < 6) {
    die "
Usage: RUM_finalcleanup.pl <rum_unique> <rum_nu> <cleaned rum_unique outfile> <cleaned rum_nu outfile> <genome seq> <sam header> [options]

Where: 
  <sam header> is the name of the outfile that has the header that will be used in the sam file

Options:
   -faok  : the fasta file already has sequence all on one line
   -countmismatches : report in the final column the number of mismatches, ignoring insertions

This script modifies the RUM_Unique and RUM_NU files to clean
up things like mismatches at the ends of alignments.

";

}
$faok = "false";
$countmismatches = "false";
for($i=6; $i<@ARGV; $i++) {
    $optionrecognized = 0;
    if($ARGV[$i] eq "-faok") {
	$faok = "true";
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-countmismatches") {
	$countmismatches = "true";
	$optionrecognized = 1;
    }
    if($optionrecognized == 0) {
	die "\nERROR: option '$ARGV[$i]' not recognized\n";
    }
}

if($faok eq "false") {
    print STDERR "Modifying genome fa file\n";
    $r = int(rand(1000));
    $f = "temp_" . $r . ".fa";
    open(OUTFILE, ">$f");
    open(INFILE, $ARGV[4]);
    $flag = 0;
    while($line = <INFILE>) {
	if($line =~ />/) {
	    if($flag == 0) {
		print OUTFILE $line;
		$flag = 1;
	    } else {
		print OUTFILE "\n$line";
	    }
	} else {
	    chomp($line);
	    print OUTFILE $line;
	}
    }
    print OUTFILE "\n";
    close(OUTFILE);
    close(INFILE);
    open(GENOMESEQ, $f);
} else {
    open(GENOMESEQ, $ARGV[4]);
}
open(OUTFILE, ">$ARGV[2]");
close(OUTFILE);
open(OUTFILE, ">$ARGV[3]");
close(OUTFILE);

$FLAG = 0;

while($FLAG == 0) {
    undef %CHR2SEQ;
    $sizeflag = 0;
    $totalsize = 0;
    while($sizeflag == 0) {
	$line = <GENOMESEQ>;
	if($line eq '') {
	    $FLAG = 1;
	    $sizeflag = 1;
	} else {
	    chomp($line);
	    $line =~ />(.*)/;
	    $chr = $1;
	    $chr =~ s/:[^:]*$//;
	    $ref_seq = <GENOMESEQ>;
	    chomp($ref_seq);
	    $chrsize = length($ref_seq);
	    $samheader{$chr} = "\@SQ\tSN:$chr\tLN:$chrsize\n";
	    $CHR2SEQ{$chr} = $ref_seq;
	    $totalsize = $totalsize + length($ref_seq);
	    if($totalsize > 1000000000) {  # don't store more than 1 gb of sequence in memory at once...
		$sizeflag = 1;
	    }
	}
    }
    &clean($ARGV[0], $ARGV[2]);
    &clean($ARGV[1], $ARGV[3]);
}
close(GENOMESEQ);

open(SAMHEADER, ">$ARGV[5]");
foreach $chr (sort cmpChrs keys %samheader) {
    $outstr = $samheader{$chr};
    print SAMHEADER $outstr;
}
close(SAMHEADER);

sub cmpChrs () {
    $a2_c = lc($b);
    $b2_c = lc($a);
    if($a2_c =~ /chr(\d+)$/ && !($b2_c =~ /chr(\d+)$/)) {
	return 1;
    }
    if($b2_c =~ /chr(\d+)$/ && !($a2_c =~ /chr(\d+)$/)) {
	return -1;
    }
    if($a2_c =~ /chr([a-z])$/ && !($b2_c =~ /chr(\d+)$/) && !($b2_c =~ /chr[a-z]+$/)) {
	return 1;
    }
    if($b2_c =~ /chr([a-z])$/ && !($a2_c =~ /chr(\d+)$/) && !($a2_c =~ /chr[a-z]+$/)) {
	return -1;
    }
    if($a2_c =~ /chr[^xy\d]/ && (($b2_c =~ /chrx/) || ($b2_c =~ /chry/))) {
	return -1;
    }
    if($b2_c =~ /chr[^xy\d]/ && (($a2_c =~ /chrx/) || ($a2_c =~ /chry/))) {
	return 1;
    }
    
    if($a2_c =~ /chr(\d+)/) {
	$numa = $1;
	if($b2_c =~ /chr(\d+)/) {
	    $numb = $1;
	    if($numa <= $numb) {return 1;} else {return -1;}
	} else {
	    return 1;
	}
    }
    if($a2_c =~ /chr([a-z]+)/) {
	$letter_a = $1;
	if($b2_c =~ /chr([a-z]+)/) {
	    $letter_b = $1;
	    if($letter_a le $letter_b) {return 1;} else {return -1;}
	} else {
	    return -1;
	}
    }
    $flag_c = 0;
    while($flag_c == 0) {
	$flag_c = 1;
	if($a2_c =~ /^([^\d]*)(\d+)/) {
	    $stem1_c = $1;
	    $num1_c = $2;
	    if($b2_c =~ /^([^\d]*)(\d+)/) {
		$stem2_c = $1;
		$num2_c = $2;
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

    return 1;
}

sub clean () {
    ($infilename, $outfilename) = @_;
    open(INFILE, $infilename);
    open(OUTFILE, ">>$outfilename");
    while($line = <INFILE>) {
	$flag = 0;
	chomp($line);
	@a = split(/\t/,$line);
	$strand = $a[4];
	$chr = $a[1];
	@b2 = split(/, /,$a[2]);
	for($i=0; $i<@b2; $i++) {
	    @c2 = split(/-/,$b2[$i]);
	    if($c2[1] < $c2[0]) {
		$flag = 1;
	    }
	}
	if(defined $CHR2SEQ{$a[1]} && $flag == 0) {
	    if($line =~ /[^\t]\+[^\t]/) {   # insertions will break things, have to fix this, for now not just cleaning these lines
		@LINE = split(/\t/,$line);
		print OUTFILE "$LINE[0]\t$LINE[1]\t$LINE[2]\t$LINE[4]\t$LINE[3]\n";
	    } else {
		@b = split(/, /, $a[2]);
		$SEQ = "";
		for($i=0; $i<@b; $i++) {
 		    @c = split(/-/,$b[$i]);
		    $len = $c[1] - $c[0] + 1;
		    $start = $c[0] - 1;
		    $SEQ = $SEQ . substr($CHR2SEQ{$a[1]}, $start, $len);
		}
		$a[3] =~ s/://g;
		&trimleft($SEQ, $a[3], $a[2]) =~ /(.*)\t(.*)/;
		$spans = $1;
		$seq = $2;
		$length1 = length($seq);
		$length2 = length($SEQ);
		for($i=0; $i<$length2 - $length1; $i++) {
		    $SEQ =~ s/^.//;
		}
		$seq =~ s/://g;
		&trimright($SEQ, $seq, $spans) =~ /(.*)\t(.*)/;
		$spans = $1;
		$seq = $2;
		$seq = addJunctionsToSeq($seq, $spans);

		# should fix the following so it doesn't repeat the operation unnecessarily
		# while processin the RUM_NU file
		if($countmismatches eq "true") {
		    $num_mismatches = &countmismatches($SEQ, $seq);
		    print OUTFILE "$a[0]\t$chr\t$spans\t$strand\t$seq\t$num_mismatches\n";
		} else {
		    print OUTFILE "$a[0]\t$chr\t$spans\t$strand\t$seq\n";
		}
	    }
	}
    }
    close(INFILE);
    close(OUTFILE);
}

sub removefirst () {
    ($n_1, $spans_1, $seq_1) = @_;
    $seq_1 =~ s/://g;
    @a_1 = split(/, /, $spans_1);
    $length_1 = 0;
    @b_1 = split(/-/,$a_1[0]);
    $length_1 = $b_1[1] - $b_1[0] + 1;
    if($length_1 <= $n_1) {
	$m_1 = $n_1 - $length_1;
	$spans2_1 = $spans_1;
	$spans2_1 =~ s/^\d+-\d+, //;
	for($j_1=0; $j_1<$length_1; $j_1++) {
	    $seq_1 =~ s/^.//;
	}
	$return = removefirst($m_1, $spans2_1, $seq_1);
	return $return;
    } else {
	for($j_1=0; $j_1<$n_1; $j_1++) {
	    $seq_1 =~ s/^.//;
	}
	$spans_1 =~ /^(\d+)-/;
	$start_1 = $1 + $n_1;
	$spans_1 =~ s/^(\d+)-/$start_1-/;
	return $spans_1 . "\t" . $seq_1;
    }
}

sub removelast () {
    ($n_1, $spans_1, $seq_1) = @_;
    $seq_1 =~ s/://g;
    @a_1 = split(/, /, $spans_1);
    @b_1 = split(/-/,$a_1[@a_1-1]);
    $length_1 = $b_1[1] - $b_1[0] + 1;
    if($length_1 <= $n_1) {
	$m_1 = $n_1 - $length_1;
	$spans2_1 = $spans_1;
	$spans2_1 =~ s/, \d+-\d+$//;
	for($j_1=0; $j_1<$length_1; $j_1++) {
	    $seq_1 =~ s/.$//;
	}
	$return = removelast($m_1, $spans2_1, $seq_1);
	return $return;
    } else {
	for($j_1=0; $j_1<$n_1; $j_1++) {
	    $seq_1 =~ s/.$//;
	}
	$spans_1 =~ /-(\d+)$/;
	$end_1 = $1 - $n_1;
	$spans_1 =~ s/-(\d+)$/-$end_1/;
	return $spans_1 . "\t" . $seq_1;
    }
}

sub trimleft () {
    ($seq1_2, $seq2_2, $spans_2) = @_;
    # seq2_2 is the one that gets modified and returned

    $seq1_2 =~ s/://g;
    $seq1_2 =~ /^(.)(.)/;
    $genomebase_2[0] = $1;
    $genomebase_2[1] = $2;
    $seq2_2 =~ s/://g;
    $seq2_2 =~ /^(.)(.)/;
    $readbase_2[0] = $1;
    $readbase_2[1] = $2;
    $mismatch_count_2 = 0;
    for($j_2=0; $j_2<2; $j_2++) {
	if($genomebase_2[$j_2] eq $readbase_2[$j_2]) {
	    $equal_2[$j_2] = 1;
	} else {
	    $equal_2[$j_2] = 0;
	    $mismatch_count_2++;
	}
    }
    if($mismatch_count_2 == 0) {
	return $spans_2 . "\t" . $seq2_2;
    }
    if($mismatch_count_2 == 1 && $equal_2[0] == 0) {
	&removefirst(1, $spans_2, $seq2_2) =~ /^(.*)\t(.*)/;
	$spans_new_2 = $1;
	$seq2_new_2 = $2;
	$seq1_2 =~ s/^.//;
	$return = &trimleft($seq1_2, $seq2_new_2, $spans_new_2);
	return $return;
    }
    if($equal_2[1] == 0 || $mismatch_count_2 == 2) {
	&removefirst(2, $spans_2, $seq2_2) =~ /^(.*)\t(.*)/;
	$spans_new_2 = $1;
	$seq2_new_2 = $2;
	$seq1_2 =~ s/^..//;
	$return = &trimleft($seq1_2, $seq2_new_2, $spans_new_2);
	return $return;
    }
}

sub trimright () {
    ($seq1_2, $seq2_2, $spans_2) = @_;
    # seq2_2 is the one that gets modified and returned

    $seq1_2 =~ s/://g;
    $seq1_2 =~ /(.)(.)$/;
    $genomebase_2[0] = $2;
    $genomebase_2[1] = $1;
    $seq2_2 =~ s/://g;
    $seq2_2 =~ /(.)(.)$/;
    $readbase_2[0] = $2;
    $readbase_2[1] = $1;
    $mismatch_count_2 = 0;

    for($j_2=0; $j_2<2; $j_2++) {
	if($genomebase_2[$j_2] eq $readbase_2[$j_2]) {
	    $equal_2[$j_2] = 1;
	} else {
	    $equal_2[$j_2] = 0;
	    $mismatch_count_2++;
	}
    }
    if($mismatch_count_2 == 0) {
	return $spans_2 . "\t" . $seq2_2;
    }
    if($mismatch_count_2 == 1 && $equal_2[0] == 0) {
	&removelast(1, $spans_2, $seq2_2) =~ /(.*)\t(.*)$/;
	$spans_new_2 = $1;
	$seq2_new_2 = $2;
	$seq1_2 =~ s/.$//;
	$return = &trimright($seq1_2, $seq2_new_2, $spans_new_2);
	return $return;
    }
    if($equal_2[1] == 0 || $mismatch_count_2 == 2) {
	&removelast(2, $spans_2, $seq2_2) =~ /(.*)\t(.*)$/;
	$spans_new_2 = $1;
	$seq2_new_2 = $2;
	$seq1_2 =~ s/..$//;
	$return = &trimright($seq1_2, $seq2_new_2, $spans_new_2);
	return $return;
    }
}

sub addJunctionsToSeq () {
    ($seq_in, $spans_in) = @_;
    @s1 = split(//,$seq_in);
    @b1 = split(/, /,$spans_in);
    $seq_out = "";
    $place = 0;
    for($j1=0; $j1<@b1; $j1++) {
	@c1 = split(/-/,$b1[$j1]);
	$len1 = $c1[1] - $c1[0] + 1;
	if($seq_out =~ /\S/) {
	    $seq_out = $seq_out . ":";
	}
	for($k1=0; $k1<$len1; $k1++) {
	    $seq_out = $seq_out . $s1[$place];
	    $place++;
	}
    }
    return $seq_out;
}

sub countmismatches () {
    ($seq1m, $seq2m) = @_;
    # seq2m is the "read"

    $seq1m =~ s/://g;
    $seq2m =~ s/://g;
    $seq2m =~ s/\+[^+]\+//g;

    @C1 = split(//,$seq1m);
    @C2 = split(//,$seq2m);
    $NUM=0;
    for($k=0; $k<@C1; $k++) {
	if($C1[$k] ne $C2[$k]) {
	    $NUM++;
	}
    }
    return $NUM;
}
