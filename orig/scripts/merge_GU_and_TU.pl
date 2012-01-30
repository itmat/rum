#!/usr/bin/perl

# Written by Gregory R. Grant
# University of Pennsylvania, 2010

$|=1;

if(@ARGV < 7) {
    die "
Usage: merge_GU_and_TU.pl <GU infile> <TU infile> <GNU infile> <TNU infile> <BowtieUnique outfile> <CNU outfile> <type>

Where:   <GU infile> is the file of unique mappers that is output from the
                     script make_GU_and_GNU.pl

         <TU infile> is the file of unique mappers that is output from the
                     script make_TU_and_TNU.pl

         <GNU infile> is the file of non-unique mappers that is output from
                      the script make_GU_and_GNU.pl

         <TNU infile> is the file of non-unique mappers that is output from
                      the script make_TU_and_TNU.pl

         <BowtieUnique outfile> is the name of the file of unique mappers to be output

         <CNU outfile> is the name of the file of non-unique mappers to be output

         <type> is 'single' for single-end reads, or 'paired' for paired-end reads

  Options:
         -readlength n  : The read length, if not specified I will try to determine it,
                          but if there aren't enough well mapped reads I might not get
                          it right.  If there are variable read lengths, set n=v.

         -maxpairdist N : N is an integer greater than zero representing
                          the furthest apart the forward and reverse reads
                          can be.  They could be separated by an exon/exon
                          junction so this number can be as large as the largest
                          intron.  Default value = 500,000

";
}

$infile1 = $ARGV[2];
$infile2 = $ARGV[3];
$infile3 = $ARGV[0];
$infile4 = $ARGV[1];
$outfile1 = $ARGV[4];
$outfile2 = $ARGV[5];
$type = $ARGV[6];
$typerecognized = 1;
if($type eq "single") {
    $paired_end = "false";
    $typerecognized = 0;
}
if($type eq "paired") {
    $paired_end = "true";
    $typerecognized = 0;
}
if($typerecognized == 1) {
    die "\nERROR: type '$type' not recognized.  Must be 'single' or 'paired'.\n";
}

$max_distance_between_paired_reads = 500000;

$readlength = 0;
for($i=7; $i<@ARGV; $i++) {
    $optionrecognized = 0;
    if($ARGV[$i] eq "-maxpairdist") {
	$i++;
	$max_distance_between_paired_reads = $ARGV[$i];
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-readlength") {
	$i++;
	$readlength = $ARGV[$i];
	if(!($readlength =~ /^\d+$/) && !($readlength eq 'v')) {
	    die "\nERROR: -readlength must be a positive integer > 4, or 'v', '$ARGV[$i]' not recognized\n";
	}
	if($readlength ne "v" && $readlength < 5) {
	    die "\nERROR: -readlength cannot be that small, must be at least 5, or 'v', '$ARGV[$i]' not valid\n";
	}
	$optionrecognized = 1;
    }

    if($optionrecognized == 0) {
	die "\nERROR: option '$ARGV[$i-1] $ARGV[$i]' not recognized\n";
    }
}

open(INFILE, $infile4) or die "\nERROR: Cannot open file '$infile4' for reading\n";

if($readlength == 0) {
    $cnt = 0;
    while($line = <INFILE>) {
	$length = 0;
	if($line =~ /seq.\d+a/ || $line =~ /seq.\d+b/) {
	    chomp($line);
	    @a = split(/\t/,$line);
	    $span = $a[2];
	    @SPANS = split(/, /, $span);
	    $cnt++;
	    for($i=0; $i<@SPANS; $i++) {
		@b = split(/-/,$SPANS[$i]);
		$length = $length + $b[1] - $b[0] + 1;
	    }
	    if($length > $readlength) {
		$readlength = $length;
		$cnt = 0;
	    }
	    if($cnt > 50000) {
		last;
	    }
	}
    }
    close(INFILE);
    open(INFILE, $infile3) or die "\nERROR: Cannot open file '$infile3' for reading\n";
    $cnt = 0;
    while($line = <INFILE>) {
	$length = 0;
	if($line =~ /seq.\d+a/ || $line =~ /seq.\d+b/) {
	    chomp($line);
	    @a = split(/\t/,$line);
	    $span = $a[2];
	    @SPANS = split(/, /, $span);
	    $cnt++;
	    for($i=0; $i<@SPANS; $i++) {
		@b = split(/-/,$SPANS[$i]);
		$length = $length + $b[1] - $b[0] + 1;
	    }
	    if($length > $readlength) {
		$readlength = $length;
		$cnt = 0;
	    }
	    if($cnt > 50000) {
		last;
	    }
	}
    }
    close(INFILE);
    $cnt = 0;
    open(INFILE, $infile1) or die "\nERROR: Cannot open file '$infile1' for reading\n";
    while($line = <INFILE>) {
	if($line =~ /seq.\d+a/ || $line =~ /seq.\d+b/) {
	    chomp($line);
	    @a = split(/\t/,$line);
	    $span = $a[2];
	    if(!($span =~ /,/)) {
		$cnt++;
		@b = split(/-/,$span);
		$length = $b[1] - $b[0] + 1;
		if($length > $readlength) {
		    $readlength = $length;
		    $cnt = 0;
		}
		if($cnt > 50000) { # it checked 50,000 lines without finding anything larger than the last time
		    # readlength was changed, so it's most certainly found the max.
		    # Went through this to avoid the user having to input the readlength.
		    last;
		}
	    }
	}
    }
    close(INFILE);
    $cnt = 0;
    open(INFILE, $infile2) or die "\nERROR: Cannot open file '$infile3' for reading\n";
    while($line = <INFILE>) {
	if($line =~ /seq.\d+a/ || $line =~ /seq.\d+b/) {
	    chomp($line);
	    @a = split(/\t/,$line);
	    $span = $a[2];
	    if(!($span =~ /,/)) {
		$cnt++;
		@b = split(/-/,$span);
		$length = $b[1] - $b[0] + 1;
		if($length > $readlength) {
		    $readlength = $length;
		    $cnt = 0;
		}
		if($cnt > 50000) { # it checked 50,000 lines without finding anything larger than the last time
		    # readlength was changed, so it's most certainly found the max.
		    # Went through this to avoid the user having to input the readlength.
		    last;
		}
	    }
	}
    }
    close(INFILE);
}
if($readlength == 0) {  # Couldn't determine the read length so going to fall back
                        # on the strategy used for variable length reads.
    $readlength = "v";
}

if(!($readlength eq "v")) {
    if($readlength < 80) {
	$min_overlap = 35;
    } else {
	$min_overlap = 45;
    }
    if($min_overlap >= .8 * $readlength) {
	$min_overlap = int(.6 * $readlength);
    }
    $min_overlap1 = $min_overlap;
    $min_overlap2 = $min_overlap;
}
open(INFILE, $infile1) or die "\nERROR: Cannot open file '$infile1' for reading\n";
while($line = <INFILE>) {
    $line =~ /^seq.(\d+)/;
    $ambiguous_mappers{$1}++;
}
close(INFILE);
open(INFILE, $infile2) or die "\nERROR: Cannot open file '$infile2' for reading\n";
while($line = <INFILE>) {
    $line =~ /^seq.(\d+)/;
    $ambiguous_mappers{$1}++;
}
close(INFILE);
open(INFILE1, $infile3) or die "\nERROR: Cannot open file '$infile3' for reading\n";
open(INFILE2, $infile4) or die "\nERROR: Cannot open file '$infile4' for reading\n";
open(OUTFILE1, ">$outfile1") or die "\nERROR: Cannot open file '$outfile1' for writing\n";
open(OUTFILE2, ">$outfile2") or die "\nERROR: Cannot open file '$outfile2' for writing\n";

$num_lines_at_once = 10000;
$linecount = 0;
$FLAG = 1;
$line_prev = <INFILE2>;
chomp($line_prev);
while($FLAG == 1) {
    undef %hash1;
    undef %hash2;
    undef %allids;
    $linecount = 0;
    until($linecount == $num_lines_at_once) {
	$line=<INFILE1>;
	if(!($line =~ /\S/)) {
	    $FLAG = 0;
	    $linecount = $num_lines_at_once;
	}
	else {
	    chomp($line);
	    @a = split(/\t/,$line);
	    $a[0] =~ /seq.(\d+)/;
	    $id = $1;
	    $last_id = $id;
	    $allids{$id}++;
	    if($a[0] =~ /a$/ || $a[0] =~ /b$/) {
		$hash1{$id}[0]++;
		$hash1{$id}[$hash1{$id}[0]]=$line;
	    }
	    else {
		$hash1{$id}[0]=-1;
		$hash1{$id}[1]=$line;
	    }
	    if($paired_end eq "true") {
		# this makes sure we have read in both a and b reads, this approach might cause a problem
		# for paired end data if no, or very few, b reads mapped at all.
		if( (($linecount == ($num_lines_at_once - 1)) && !($a[0] =~ /a$/)) || ($linecount < ($num_lines_at_once - 1)) ) {
		    $linecount++;
		}
	    }
	    else {
		if( ($linecount == ($num_lines_at_once - 1)) || ($linecount < ($num_lines_at_once - 1)) ) {
		    $linecount++;
		}
	    }
	}
    }
    $line = $line_prev;
    @a = split(/\t/,$line);
    $a[0] =~ /seq.(\d+)/;
    $prev_id = $id;
    $id = $1;
    if($prev_id eq $id) {
	$FLAG2 = 0;
    }
    $FLAG2 = 1;
    until($id > $last_id || $FLAG2 == 0) {
	$allids{$id}++;
	if($a[0] =~ /a$/ || $a[0] =~ /b$/) {
	    $hash2{$id}[0]++;
	    $hash2{$id}[$hash2{$id}[0]]=$line;
	}
	else {
	    $hash2{$id}[0]=-1;
	    $hash2{$id}[1]=$line;
	}
	$line=<INFILE2>;
	chomp($line);
	if(!($line =~ /\S/)) {
	    $FLAG2 = 0;
	}
	else {
	    @a = split(/\t/,$line);
	    $a[0] =~ /seq.(\d+)/;
	    $id = $1;
	}
    }
    if($FLAG2 == 1) {
	$line_prev = $line;
    }
    foreach $id (sort {$a <=> $b} keys %allids) {
	if($ambiguous_mappers{$id}+0 > 0) {
	    next;
	}
	$hash1{$id}[0] = $hash1{$id}[0] + 0;
	$hash2{$id}[0] = $hash2{$id}[0] + 0;
	# MUST DO 15 CASES IN TOTAL:
	# THREE CASES:
	if($hash1{$id}[0] == 0) {
	    # no genome mapper, so there must be a transcriptome mapper
	    if($hash2{$id}[0] == -1) {
		print OUTFILE1 "$hash2{$id}[1]\n";
	    }
	    else {
		for($i=0; $i<$hash2{$id}[0]; $i++) {
		    print OUTFILE1 "$hash2{$id}[$i+1]\n";
		}
	    }
	}
	# THREE CASES
	if($hash2{$id}[0] == 0) {
	    # no transcriptome mapper, so there must be a genome mapper
	    if($hash1{$id}[0] == -1) {
		print OUTFILE1 "$hash1{$id}[1]\n";
	    }
	    else {
		for($i=0; $i<$hash1{$id}[0]; $i++) {
		    print OUTFILE1 "$hash1{$id}[$i+1]\n";
		}
	    }
	}
	# ONE CASE
	if($hash1{$id}[0] == -1 && $hash2{$id}[0] == -1) {
	    # genome mapper and transcriptome mapper, and both joined
	    undef @spans;
	    @a1 = split(/\t/,$hash1{$id}[1]);
	    @a2 = split(/\t/,$hash2{$id}[1]);
	    $spans[0] = $a1[2];
	    $spans[1] = $a2[2];
	    $str = intersect(\@spans, $a1[3]);
	    $str =~ /^(\d+)/;
	    $length_overlap = $1;

	    if($readlength eq "v") {
		$readlength_temp = length($a1[3]);
		if(length($a2[3]) < $readlength_temp) {
		    $readlength_temp = length($a2[3]);
		}
		if($readlength_temp < 80) {
		    $min_overlap = 35;
		} else {
		    $min_overlap = 45;
		}
		if($min_overlap >= .8 * $readlength_temp) {
		    $min_overlap = int(.6 * $readlength_temp);
		}
	    }
	    if(($length_overlap > $min_overlap) && ($a1[1] eq $a2[1])) {
		print OUTFILE1 "$hash2{$id}[1]\n";
	    }
	    else {
		print OUTFILE2 "$hash1{$id}[1]\n";
		print OUTFILE2 "$hash2{$id}[1]\n";
	    }
	}
	# ONE CASE
	if($hash1{$id}[0] == 1 && $hash2{$id}[0] == 1) {
	    # genome mapper and transcriptome mapper, and both single read mapping
	    # If single-end then this is the only case where $hash1{$id}[0] > 0 and $hash2{$id}[0] > 0
	    if((($hash1{$id}[1] =~ /seq.\d+a/) && ($hash2{$id}[1] =~ /seq.\d+a/)) || (($hash1{$id}[1] =~ /seq.\d+b/) && ($hash2{$id}[1] =~ /seq.\d+b/))) {
		# both forward mappers, or both reverse mappers
		undef @spans;
		@a1 = split(/\t/,$hash1{$id}[1]);
		@a2 = split(/\t/,$hash2{$id}[1]);
		$spans[0] = $a1[2];
		$spans[1] = $a2[2];
		$str = intersect(\@spans, $a1[3]);
		$str =~ /^(\d+)/;
		$length_overlap = $1;

		if($readlength eq "v") {
		    $readlength_temp = length($a1[3]);
		    if(length($a2[3]) < $readlength_temp) {
			$readlength_temp = length($a2[3]);
		    }
		    if($readlength_temp < 80) {
			$min_overlap = 35;
		    } else {
			$min_overlap = 45;
		    }
		    if($min_overlap >= .8 * $readlength_temp) {
			$min_overlap = int(.6 * $readlength_temp);
		    }
		}
		
		if(($length_overlap > $min_overlap) && ($a1[1] eq $a2[1])) {
                    # preference TU
		    print OUTFILE1 "$hash2{$id}[1]\n";
		}
		else {
		    if($paired_end eq "false") {
			print OUTFILE2 "$hash1{$id}[1]\n";			
			print OUTFILE2 "$hash2{$id}[1]\n";			
		    }
		}
	    }
	    if((($hash1{$id}[1] =~ /seq.\d+a/) && ($hash2{$id}[1] =~ /seq.\d+b/)) || (($hash1{$id}[1] =~ /seq.\d+b/) && ($hash2{$id}[1] =~ /seq.\d+a/))) {
		# one forward and one reverse
		@a = split(/\t/,$hash1{$id}[1]);
		$aspans = $a[2];
		$a[2] =~ /^(\d+)[^\d]/;
		$astart = $1;
		$a[2] =~ /[^\d](\d+)$/;
		$aend = $1;
		$chra = $a[1];
		$aseq = $a[3];
		$seqnum = $a[0];
		$atype = "";
		if($seqnum =~ s/a$//) {
		    $atype = "forward";
		}
		if($seqnum =~ s/b$//) {
		    $atype = "reverse";
		}
		$astrand = $a[4];
		if($atype eq "forward") {
		    if($astrand eq "+") {
			$forward_strand = "+";
		    }
		    if($astrand eq "-") {
			$forward_strand = "-";
		    }
		} else {
		    if($bstrand eq "+") {
			$forward_strand = "+";
		    }
		    if($bstrand eq "-") {
			$forward_strand = "-";
		    }
		}

		@a = split(/\t/,$hash2{$id}[1]);
		$btype = "";
		if($a[0] =~ /a$/) {
		    $btype = "forward";
		}
		if($a[0] =~ /b$/) {
		    $btype = "reverse";
		}

		$bspans = $a[2];
		$a[2] =~ /^(\d+)[^\d]/;
		$bstart = $1;
		$a[2] =~ /[^\d](\d+)$/;
		$bend = $1;
		$chrb = $a[1];
		$bseq = $a[3];
		$bstrand = $a[4];
		if($btype eq "forward") {
		    if($bstrand eq "+") {
			$forward_strand = "+";
		    }
		    if($bstrand eq "-") {
			$forward_strand = "-";
		    }
		} else {
		    if($astrand eq "+") {
			$forward_strand = "+";
		    }
		    if($astrand eq "-") {
			$forward_strand = "-";
		    }
		}

 # the next two if's take care of the case that there is no overlap, one read lies entirely downstream of the other
		
		if((($astrand eq "+" && $bstrand eq "+" && $atype eq "forward" && $btype eq "reverse") || ($astrand eq "-" && $bstrand eq "-" && $atype eq "reverse" && $btype eq "forward")) && ($chra eq $chrb) && ($aend < $bstart-1) && ($bstart - $aend < $max_distance_between_paired_reads)) {
		    if($hash1{$id}[1] =~ /a\t/) {
			print OUTFILE1 "$hash1{$id}[1]\n$hash2{$id}[1]\n";
		    }
		    else {
			print OUTFILE1 "$hash2{$id}[1]\n$hash1{$id}[1]\n";
		    }
		}
		if((($astrand eq "-" && $bstrand eq "-" && $atype eq "forward" && $btype eq "reverse") || ($astrand eq "+" && $bstrand eq "+" && $atype eq "reverse" && $btype eq "forward")) && ($chra eq $chrb) && ($bend < $astart-1) && ($astart - $bend < $max_distance_between_paired_reads)) {
		    if($hash1{$id}[1] =~ /a\t/) {
			print OUTFILE1 "$hash1{$id}[1]\n$hash2{$id}[1]\n";
		    }
		    else {
			print OUTFILE1 "$hash2{$id}[1]\n$hash1{$id}[1]\n";
		    }
		}
		$Eflag =0;

		if(($astrand eq $bstrand) && ($chra eq $chrb) && (($aend >= $bstart-1) && ($astart <= $bstart)) || (($bend >= $astart-1) && ($bstart <= $astart))) {

		    $aseq2 = $aseq;
		    $aseq2 =~ s/://g;
		    $bseq2 = $bseq;
		    $bseq2 =~ s/://g;
		    if($atype eq "forward" && $astrand eq "+" || $atype eq "reverse" && $astrand eq "-") {
			($merged_spans, $merged_seq) = merge($aspans, $bspans, $aseq2, $bseq2);
		    } else {
			($merged_spans, $merged_seq) = merge($bspans, $aspans, $bseq2, $aseq2);
		    }
		    if(!($merged_spans =~ /\S/)) {
			@AS = split(/-/,$aspans);
			$AS[0]++;
			$aspans_temp = $AS[0] . "-" . $AS[1]; 
			$aseq2_temp = $aseq2;
			$aseq2_temp =~ s/^.//;
			if($atype eq "forward" && $astrand eq "+" || $atype eq "reverse" && $astrand eq "-") {
			    ($merged_spans, $merged_seq) = merge($aspans_temp, $bspans, $aseq2_temp, $bseq2);
			} else {
			    ($merged_spans, $merged_seq) = merge($bspans, $aspans_temp, $bseq2, $aseq2_temp);
			}
		    }
		    if(!($merged_spans =~ /\S/)) {
			$AS[0]++;
			$aspans_temp = $AS[0] . "-" . $AS[1]; 
			$aseq2_temp =~ s/^.//;
			if($atype eq "forward" && $astrand eq "+" || $atype eq "reverse" && $astrand eq "-") {
			    ($merged_spans, $merged_seq) = merge($aspans_temp, $bspans, $aseq2_temp, $bseq2);
			} else {
			    ($merged_spans, $merged_seq) = merge($bspans, $aspans_temp, $bseq2, $aseq2_temp);
			}
		    }
		    if(!($merged_spans =~ /\S/)) {
			$AS[0]++;
			$aspans_temp = $AS[0] . "-" . $AS[1]; 
			$aseq2_temp =~ s/^.//;
			if($atype eq "forward" && $astrand eq "+" || $atype eq "reverse" && $astrand eq "-") {
			    ($merged_spans, $merged_seq) = merge($aspans_temp, $bspans, $aseq2_temp, $bseq2);
			} else {
			    ($merged_spans, $merged_seq) = merge($bspans, $aspans_temp, $bseq2, $aseq2_temp);
			}
		    }
		    if(!($merged_spans =~ /\S/)) {
			@AS = split(/-/,$aspans);
			$AS[1]--;
			$aspans_temp = $AS[0] . "-" . $AS[1]; 
			$aseq2_temp = $aseq2;
			$aseq2_temp =~ s/.$//;
			if($atype eq "forward" && $astrand eq "+" || $atype eq "reverse" && $astrand eq "-") {
			    ($merged_spans, $merged_seq) = merge($aspans_temp, $bspans, $aseq2_temp, $bseq2);
			} else {
			    ($merged_spans, $merged_seq) = merge($bspans, $aspans_temp, $bseq2, $aseq2_temp);
			}
		    }
		    if(!($merged_spans =~ /\S/)) {
			$AS[1]--;
			$aspans_temp = $AS[0] . "-" . $AS[1]; 
			$aseq2_temp =~ s/.$//;
			if($atype eq "forward" && $astrand eq "+" || $atype eq "reverse" && $astrand eq "-") {
			    ($merged_spans, $merged_seq) = merge($aspans_temp, $bspans, $aseq2_temp, $bseq2);
			} else {
			    ($merged_spans, $merged_seq) = merge($bspans, $aspans_temp, $bseq2, $aseq2_temp);
			}
		    }
		    if(!($merged_spans =~ /\S/)) {
			$AS[1]--;
			$aspans_temp = $AS[0] . "-" . $AS[1]; 
			$aseq2_temp =~ s/.$//;
			if($atype eq "forward" && $astrand eq "+" || $atype eq "reverse" && $astrand eq "-") {
			    ($merged_spans, $merged_seq) = merge($aspans_temp, $bspans, $aseq2_temp, $bseq2);
			} else {
			    ($merged_spans, $merged_seq) = merge($bspans, $aspans_temp, $bseq2, $aseq2_temp);
			}
		    }

		    if(!($merged_spans =~ /\S/)) {
			@Fspans = split(/, /,$aspans);
			@T = split(/-/, $Fspans[0]);
			$aspans3 = $aspans;
			$aseq3 = $aseq;
			$bseq3 = $bseq;
			$aseq3 =~ s/://g;
			$bseq3 =~ s/://g;
			if($T[1] - $T[0] <= 5) {
			    $aspans3 =~ s/^(\d+)-(\d+), //;
			    $length_diff = $2 - $1 + 1;
			    for($i1=0; $i1<$length_diff; $i1++) {
				$aseq3 =~ s/^.//;
			    }
			}
			if($atype eq "forward" && $astrand eq "+" || $atype eq "reverse" && $astrand eq "-") {
			    ($merged_spans, $merged_seq) = merge($aspans3, $bspans, $aseq3, $bseq3);
			} else {
			    ($merged_spans, $merged_seq) = merge($bspans, $aspans3, $bseq3, $aseq3);
			}
			if(!($merged_spans =~ /\S/)) {
			    @T = split(/-/, $Fspans[@Fspans-1]);
			    $aspans4 = $aspans;
			    $aseq4 = $aseq;
			    $bseq4 = $bseq;
			    $aseq4 =~ s/://g;
			    $bseq4 =~ s/://g;
			    if($T[1] - $T[0] <= 5) {
				$aspans4 =~ s/, (\d+)-(\d+)$//;
				$length_diff = $2 - $1 + 1;
				for($i1=0; $i1<$length_diff; $i1++) {
				    $aseq4 =~ s/.$//;
				}
			    }
			    if($atype eq "forward" && $astrand eq "+" || $atype eq "reverse" && $astrand eq "-") {
				($merged_spans, $merged_seq) = merge($aspans4, $bspans, $aseq4, $bseq4);
			    } else {
				($merged_spans, $merged_seq) = merge($bspans, $aspans4, $bseq4, $aseq4);
			    }
			}
		    }
		    if(!($merged_spans =~ /\S/)) {
			@Rspans = split(/, /,$bspans);
			@T = split(/-/, $Rspans[0]);
			$bspans3 = $bspans;
			$aseq3 = $aseq;
			$bseq3 = $bseq;
			$aseq3 =~ s/://g;
			$bseq3 =~ s/://g;
			if($T[1] - $T[0] <= 5) {
			    $bspans3 =~ s/^(\d+)-(\d+), //;
			    $length_diff = $2 - $1 + 1;
			    for($i1=0; $i1<$length_diff; $i1++) {
				$bseq3 =~ s/^.//;
			    }
			}
			if($atype eq "forward" && $astrand eq "+" || $atype eq "reverse" && $astrand eq "-") {
			    ($merged_spans, $merged_seq) = merge($aspans, $bspans3, $aseq3, $bseq3);
			} else {
			    ($merged_spans, $merged_seq) = merge($bspans3, $aspans, $bseq3, $aseq3);
			}
			if(!($merged_spans =~ /\S/)) {
			    @T = split(/-/, $Rspans[@Rspans-1]);
			    $bspans4 = $bspans;
			    $aseq4 = $aseq;
			    $bseq4 = $bseq;
			    $aseq4 =~ s/://g;
			    $bseq4 =~ s/://g;
			    if($T[1] - $T[0] <= 5) {
				$bspans4 =~ s/, (\d+)-(\d+)$//;
				$length_diff = $2 - $1 + 1;
				for($i1=0; $i1<$length_diff; $i1++) {
				    $bseq4 =~ s/.$//;
				}
			    }
			    if($atype eq "forward" && $astrand eq "+" || $atype eq "reverse" && $astrand eq "-") {
				($merged_spans, $merged_seq) = merge($aspans, $bspans4, $aseq4, $bseq4);
			    } else {
				($merged_spans, $merged_seq) = merge($bspans4, $aspans, $bseq4, $aseq4);
			    }
			}
		    }
		    $seq_j = addJunctionsToSeq($merged_seq, $merged_spans);

		    if($seq_j =~ /\S/ && $merged_spans =~ /^\d+.*-.*\d+$/) {
			print OUTFILE1 "$seqnum\t$chra\t$merged_spans\t$seq_j\t$astrand\n";
		    }
		    $Eflag =1;
		}
	    }
	}
	# ONE CASE
	if($hash1{$id}[0] == 2 && $hash2{$id}[0] == 2) {
	    undef @spansa;
	    undef @spansb;
	    @a = split(/\t/,$hash1{$id}[1]);
	    $chr1 = $a[1];
	    $spansa[0] = $a[2];
	    $seqa = $a[3];
	    @a = split(/\t/,$hash1{$id}[2]);
	    $spansb[0] = $a[2];
	    $seqb = $a[3];
	    @a = split(/\t/,$hash2{$id}[1]);
	    $chr2 = $a[1];
	    $spansa[1] = $a[2];

	    if($readlength eq "v") {
		$readlength_temp = length($seqa);
		if(length($a[3]) < $readlength_temp) {
		    $readlength_temp = length($a[3]);
		}
		if($readlength_temp < 80) {
		    $min_overlap1 = 35;
		} else {
		    $min_overlap1 = 45;
		}
		if($min_overlap1 >= .8 * $readlength_temp) {
		    $min_overlap1 = int(.6 * $readlength_temp);
		}
	    }

	    @a = split(/\t/,$hash2{$id}[2]);
	    $spansb[1] = $a[2];

	    if($readlength eq "v") {
		$readlength_temp = length($seqb);
		if(length($a[3]) < $readlength_temp) {
		    $readlength_temp = length($a[3]);
		}
		if($readlength_temp < 80) {
		    $min_overlap2 = 35;
		} else {
		    $min_overlap2 = 45;
		}
		if($min_overlap2 >= .8 * $readlength_temp) {
		    $min_overlap2 = int(.6 * $readlength_temp);
		}
	    }

	    $str = intersect(\@spansa, $seqa);
	    $str =~ /^(\d+)/;
	    $length_overlap1 = $1;
	    $str = intersect(\@spansb, $seqb);
	    $str =~ /^(\d+)/;
	    $length_overlap2 = $1;
	    if(($length_overlap1 > $min_overlap1) && ($length_overlap2 > $min_overlap2) && ($chr1 eq $chr2)) {
		print OUTFILE1 "$hash2{$id}[1]\n";
		print OUTFILE1 "$hash2{$id}[2]\n";
	    }
	    else {
		print OUTFILE2 "$hash1{$id}[1]\n";
		print OUTFILE2 "$hash1{$id}[2]\n";
		print OUTFILE2 "$hash2{$id}[1]\n";
		print OUTFILE2 "$hash2{$id}[2]\n";
	    }
	}	
	# NINE CASES DONE
	# ONE CASE
	if($hash1{$id}[0] == -1 && $hash2{$id}[0] == 2) {
	    print OUTFILE2 "$hash1{$id}[1]\n";
	    print OUTFILE2 "$hash2{$id}[1]\n";
	    print OUTFILE2 "$hash2{$id}[2]\n";
	}
	# ONE CASE
	if($hash1{$id}[0] == 2 && $hash2{$id}[0] == -1) {
	    undef @spans;
	    @a = split(/\t/,$hash1{$id}[1]);
	    $chr1 = $a[1];
	    $spans[0] = $a[2];
	    $seq = $a[3];
	    @a = split(/\t/,$hash2{$id}[1]);
	    $chr2 = $a[1];
	    $spans[1] = $a[2];
	    if($chr1 eq $chr2) {
		if($readlength eq "v") {
		    $readlength_temp = length($seq);
		    if(length($a[3]) < $readlength_temp) {
			$readlength_temp = length($a[3]);
		    }
		    if($readlength_temp < 80) {
			$min_overlap1 = 35;
		    } else {
			$min_overlap1 = 45;
		    }
		    if($min_overlap1 >= .8 * $readlength_temp) {
			$min_overlap1 = int(.6 * $readlength_temp);
		    }
		}
		$str = intersect(\@spans, $seq);
		$str =~ /^(\d+)/;
		$overlap1 = $1;
		@a = split(/\t/,$hash1{$id}[2]);
		if($readlength eq "v") {
		    $readlength_temp = length($seq);
		    if(length($a[3]) < $readlength_temp) {
			$readlength_temp = length($a[3]);
		    }
		    if($readlength_temp < 80) {
			$min_overlap2 = 35;
		    } else {
			$min_overlap2 = 45;
		    }
		    if($min_overlap2 >= .8 * $readlength_temp) {
			$min_overlap2 = int(.6 * $readlength_temp);
		    }
		}
		$spans[0] = $a[2];
		$str = intersect(\@spans, $seq);
		$str =~ /^(\d+)/;
		$overlap2 = $1;
	    }
	    if($overlap1 >= $min_overlap1 && $overlap2 >= $min_overlap2) {
		print OUTFILE1 "$hash2{$id}[1]\n";
	    }
	    else {
		print OUTFILE2 "$hash1{$id}[1]\n";
		print OUTFILE2 "$hash1{$id}[2]\n";
		print OUTFILE2 "$hash2{$id}[1]\n";
	    }
	}
	# ELEVEN CASES DONE
	if($hash1{$id}[0] == -1 && $hash2{$id}[0] == 1) {
	    print OUTFILE1 "$hash1{$id}[1]\n";
	}
	if($hash1{$id}[0] == 1 && $hash2{$id}[0] == -1) {
	    print OUTFILE1 "$hash2{$id}[1]\n";
	}
	if($hash1{$id}[0] == 1 && $hash2{$id}[0] == 2) {
	    print OUTFILE1 "$hash2{$id}[1]\n";
	    print OUTFILE1 "$hash2{$id}[2]\n";
	}	
	if($hash1{$id}[0] == 2 && $hash2{$id}[0] == 1) {
	    print OUTFILE1 "$hash1{$id}[1]\n";
	    print OUTFILE1 "$hash1{$id}[2]\n";
	}	
	# ALL FIFTEEN CASES DONE
    }
}


sub intersect () {
    ($spans_ref, $seq) = @_;
    @spans = @{$spans_ref};
    $num_i = @spans;
    undef %chash;
    for($s_i=0; $s_i<$num_i; $s_i++) {
	@a_i = split(/, /,$spans[$s_i]);
	for($i_i=0;$i_i<@a_i;$i_i++) {
	    @b_i = split(/-/,$a_i[$i_i]);
	    for($j_i=$b_i[0];$j_i<=$b_i[1];$j_i++) {
		$chash{$j_i}++;
	    }
	}
    }
    $spanlength = 0;
    $flag_i = 0;
    $maxspanlength = 0;
    $maxspan_start = 0;
    $maxspan_end = 0;
    $prevkey = 0;
    for $key_i (sort {$a <=> $b} keys %chash) {
	if($chash{$key_i} == $num_i) {
	    if($flag_i == 0) {
		$flag_i = 1;
		$span_start = $key_i;
	    }
	    $spanlength++;
	}
	else {
	    if($flag_i == 1) {
		$flag_i = 0;
		if($spanlength > $maxspanlength) {
		    $maxspanlength = $spanlength;
		    $maxspan_start = $span_start;
		    $maxspan_end = $prevkey;
		}
		$spanlength = 0;
	    }
	}
	$prevkey = $key_i;
    }
    if($flag_i == 1) {
	if($spanlength > $maxspanlength) {
	    $maxspanlength = $spanlength;
	    $maxspan_start = $span_start;
	    $maxspan_end = $prevkey;
	}
    }
    if($maxspanlength > 0) {
	@a_i = split(/, /,$spans[0]);
	@b_i = split(/-/,$a_i[0]);
	$i_i=0;
	until($b_i[1] >= $maxspan_start) {
	    $i_i++;
	    @b_i = split(/-/,$a_i[$i_i]);
	}
	$prefix_size = $maxspan_start - $b_i[0];  # the size of the part removed from spans[0]
	for($j_i=0; $j_i<$i_i; $j_i++) {
	    @b_i = split(/-/,$a_i[$j_i]);
	    $prefix_size = $prefix_size + $b_i[1] - $b_i[0] + 1;
	}
	@s_i = split(//,$seq);
	$newseq = "";
	for($i_i=$prefix_size; $i_i<$prefix_size + $maxspanlength; $i_i++) {
	    $newseq = $newseq . $s_i[$i_i];
	}
	$flag_i = 0;
	$i_i=0;
	@b_i = split(/-/,$a_i[0]);
	until($b_i[1] >= $maxspan_start) {
	    $i_i++;
	    @b_i = split(/-/,$a_i[$i_i]);
	}
	$newspans = $maxspan_start;
	until($b_i[1] >= $maxspan_end) {
	    $newspans = $newspans . "-$b_i[1]";
	    $i_i++;
	    @b_i = split(/-/,$a_i[$i_i]);
	    $newspans = $newspans . ", $b_i[0]";
	}
	$newspans = $newspans . "-$maxspan_end";
	$off = "";
	for($i_i=0; $i_i<$prefix_size; $i_i++) {
	    $off = $off . " ";
	}
	return "$maxspanlength\t$newspans\t$newseq";
    }
    else {
	return "0";
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

sub merge () {
    ($upstreamspans, $downstreamspans, $seq1, $seq2) = @_;

    undef %HASH;
    undef @Uarray;
    undef @Darray;
    undef @Upstreamspans;
    undef @Downstreamspans;
    undef @Ustarts;
    undef @Dstarts;
    undef @Uends;
    undef @Dends;
    undef @T;

    @Upstreamspans = split(/, /,$upstreamspans);
    @Downstreamspans = split(/, /,$downstreamspans);
    $num_u = @Upstreamspans;
    $num_d = @Downstreamspans;
    for($i1=0; $i1<$num_u; $i1++) {
	@T = split(/-/, $Upstreamspans[$i1]);
	$Ustarts[$i1] = $T[0];
	$Uends[$i1] = $T[1];
    }
    for($i1=0; $i1<$num_d; $i1++) {
	@T = split(/-/, $Downstreamspans[$i1]);
	$Dstarts[$i1] = $T[0];
	$Dends[$i1] = $T[1];
    }
# the last few bases of the upstream read might be misaligned downstream of the entire
# downstream read, the following chops them off and tries again

    if($num_u > 1 && ($Uends[$num_u-1]-$Ustarts[$num_u-1]) <= 5) {
	if($Dends[$num_d-1] < $Uends[$num_u-1]) {
	    $upstreamspans =~ s/, (\d+)-(\d+)$//;
	    $length_diff = $2 - $1 + 1;
	    for($i1=0; $i1<$length_diff; $i1++) {
		$seq1 =~ s/.$//;
	    }
	    ($merged, $merged_seq) = merge($upstreamspans, $downstreamspans, $seq1, $seq2);
	    return ($merged, $merged_seq);
	}
    }
# similarly, the first few bases of the downstream read might be misaligned upstream of the entire
# upstream read, the following chops them off and tries again

    if($num_u > 1 && ($Dends[0]-$Dstarts[0]) <= 5) {
	if($Dstarts[0] < $Ustarts[0]) {
	    $downstreamspans =~ s/^(\d+)-(\d+), //;
	    $length_diff = $2 - $1 + 1;
	    for($i1=0; $i1<$length_diff; $i1++) {
		$seq2 =~ s/^.//;
	    }
	    ($merged, $merged_seq) = merge($upstreamspans, $downstreamspans, $seq1, $seq2);
	    return ($merged, $merged_seq);
	}
    }

# next two if statements take care of the case where they do not overlap

    if($Uends[$num_u-1] == $Dstarts[0]-1) {
	$upstreamspans =~ s/-\d+$//;
	$downstreamspans =~ s/^\d+-//;
	$seq = $seq1 . $seq2;
	$merged = $upstreamspans . "-" . $downstreamspans;
	return ($merged, $seq);
    }
    if($Uends[$num_u-1] < $Dstarts[0]-1) {
	$seq = $seq1 . $seq2;
	$merged = $upstreamspans . ", " . $downstreamspans;
	return ($merged, $seq);
    }

# now going to do a bunch of checks that these reads coords are consistent with 
# them really being overlapping

# the following merges the upstream starts and ends into one array
    for($i1=0; $i1<$num_u; $i1++) {
	$Uarray[2*$i1] = $Ustarts[$i1];
	$Uarray[2*$i1+1] = $Uends[$i1];
    }
# the following merges the downstream starts and ends into one array
    for($i1=0; $i1<$num_d; $i1++) {
	$Darray[2*$i1] = $Dstarts[$i1];
	$Darray[2*$i1+1] = $Dends[$i1];
    }
    $Flength = 0;
    $Rlength = 0;
    for($i1=0; $i1<@Uarray; $i1=$i1+2) {
	$Flength = $Flength + $Uarray[$i1+1] - $Uarray[$i1] + 1;
    }
    for($i1=0; $i1<@Darray; $i1=$i1+2) {
	$Rlength = $Rlength + $Darray[$i1+1] - $Darray[$i1] + 1;
    }
    $i1=0;
    $flag1 = 0;
# try to find a upstream span that contains the start of the downstream read
    until($i1>=@Uarray || ($Uarray[$i1] <= $Darray[0] && $Darray[0] <= $Uarray[$i1+1])) {
	$i1 = $i1+2;
    } 
    if($i1>=@Uarray) { # didn't find one...
	$flag1 = 1;
    }
    $Fhold = $Uarray[$i1];
# the following checks the spans in the overlap have the same starts and ends
    for($j1=$i1+1; $j1<@Uarray-1; $j1++) {
	if($Uarray[$j1] != $Darray[$j1-$i1]) {
	    $flag1 = 1;
	} 
    }
    $Rhold = $Darray[@Uarray-1-$i1];
# make sure the end of the upstream ends in a span of the downstream   
    if(!($Uarray[@Uarray-1] >= $Darray[@Uarray-$i1-2] && $Uarray[@Uarray-1] <= $Darray[@Uarray-$i1-1])) {
	$flag1 = 1;
    }
    $merged="";
    $Darray[0] = $Fhold;
    $Uarray[@Uarray-1] = $Rhold;
    if($flag1 == 0) { # everything is kosher, going to proceed to merge
	for($i1=0; $i1<@Uarray-1; $i1=$i1+2) {
	    $HASH{"$Uarray[$i1]-$Uarray[$i1+1]"}++;
	}
	for($i1=0; $i1<@Darray-1; $i1=$i1+2) {
	    $HASH{"$Darray[$i1]-$Darray[$i1+1]"}++;
	}
	$merged_length=0;
	foreach $key_i (sort {$a<=>$b} keys %HASH) {
	    $merged = $merged . ", $key_i";
	    @A = split(/-/,$key_i);
	    $merged_length = $merged_length + $A[1] - $A[0] + 1;
	}
	$suffix_length = $merged_length - $Flength;
	$offset = $Rlength - $suffix_length;
	$suffix = substr($seq2, $offset, $merged_length);
	$merged =~ s/\s*,\s*$//;
	$merged =~ s/^\s*,\s*//;
	$merged_seq = $seq1 . $suffix;
	return ($merged, $merged_seq);
    }
}
