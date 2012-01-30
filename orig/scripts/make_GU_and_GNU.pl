#!/usr/bin/perl

# Written by Gregory R. Grant
# University of Pennsylvania, 2010

$|=1;

if(@ARGV < 4) {
    print STDERR 
"
Usage: make_GU_and_GNU.pl <input_filename> <gu_filename> <tu_filename> <type> [options]

  Where: <input_filename> is the file output from sort_bowtie.pl

         <gu_filename> is the name of the file to be written that will contain
                       unique genome alignments

         <gnu_filename> is the name of the file to be written that will contain
                        non-nique genome alignments

         <type> is 'single' for single-end reads, or 'paired' for paired-end reads

  Options:
         -maxpairdist N : N is an integer greater than zero representing
                          the furthest apart the forward and reverse reads
                          can be.  They could be separated by an exon/exon
                          junction so this number can be as large as the largest
                          intron.  Default value = 500,000

  INPUT:
  -----
  This script takes the output of a bowtie mapping against the genome, which has
  been sorted by sort_bowtie.pl, and parses it to have the four columns:
        1) read name
        2) chromosome
        3) span
        4) sequence
  A line of the (input) bowtie file should look like:
  seq.1a   -   chr14   1031657   CACCTAATCATACAAGTTTGGCTAGTGGAAAA

  Sequence names are expected to be of the form seq.Na where N in an integer
  greater than 0.  The 'a' signifies this is a 'forward' read, and 'b' signifies
  'reverse' reads.  The file may consist of all forward reads (single-end data), or
  it may have both forward and reverse reads (paired-end data).  Even if single-end
  the sequence names still must end with an 'a'.

  OUTPUT:
  ------
  The line above is modified by the script to be:
  seq.1a   chr14   1031658-1031689   CACCTAATCATACAAGTTTGGCTAGTGGAAAA

  In the case of single-end reads, if there is a unique such line for seq.1a then
  it is written to the file specified by <gu_filename>.  If there are multiple lines for
  seq.1a then they are all written to the file specified by <gnu_filename>.

  In the case of paired-end reads the script tries to match up entries for seq.1a
  and seq.1b consistently, which means:
        1) both reads are on the same chromosome
        2) the two reads map in opposite orientations
        3) the start of reads are further apart than ends of reads
           and no further apart than $max_distance_between_paired_reads

  If the two reads do not overlap then the consistent mapper is represented by two
  consecutive lines, the forward (a) read first and the reverse (b) read second.
  If the two reads overlap then they two lines are merged into one line and the
  a/b designation is removed.

  If there is a unique consistent mapper it is written to the file specified  by
  <gu_filename>.  If there are multiple consistent mappers they are all written to
  the file specified by <gnu_filename>.  If only the forward or reverse read map
  then it does not write anything.

";
    exit(1);
}

$infile = $ARGV[0];
$outfile1 = $ARGV[1];
$outfile2 = $ARGV[2];
$type = $ARGV[3];
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
for($i=4; $i<@ARGV; $i++) {
    $optionrecognized = 0;
    if($ARGV[$i] eq "-maxpairdist") {
	$i++;
	$max_distance_between_paired_reads = $ARGV[$i];
	$optionrecognized = 1;
    }

    if($optionrecognized == 0) {
	die "\nERROR: option '$ARGV[$i-1] $ARGV[$i]' not recognized\n";
    }
}

open(INFILE, $infile) or die "\nERROR: Cannot open infile '$infile'\n";
$t = `tail -1 $infile`;
$t =~ /seq.(\d+)/;
$num_seqs = $1;
$line = <INFILE>;
chomp($line);
open(OUTFILE1, ">$outfile1") or die "\nERROR: Cannot open file '$outfile1' for writing\n";
open(OUTFILE2, ">$outfile2") or die "\nERROR: Cannot open file '$outfile2' for writing\n";
print "num_seqs = $num_seqs\n";
for($seqnum=1; $seqnum<=$num_seqs; $seqnum++) {
    $numa=0;
    $numb=0;
    undef %a_reads;
    undef %b_reads;
    while($line =~ /seq.($seqnum)a/) {
	$seqs_a[$numa] = $line;
	$numa++;
	$line = <INFILE>;
	chomp($line);
    }
    while($line =~ /seq.($seqnum)b/) {
	$seqs_b[$numb] = $line;
	$numb++;
	$line = <INFILE>;
	chomp($line);
    }
    if($numa > 0 || $numb > 0) {
	$num_different_a = 0;
	for($i=0; $i<$numa; $i++) {
	    $line2 = $seqs_a[$i];
	    if(!($line2 =~ /^N+$/)) {
		@a = split(/\t/,$line2);
		$id = $a[0];
		$strand = $a[1];
		$chr = $a[2];
		$chr =~ s/:.*//;
		$start = $a[3]+1;
		$seq = $a[4];
		if($seq =~ /^(N+)/) {
		    $seq =~ s/^(N+)//;
		    $Nprefix = $1;
		    @x = split(//,$Nprefix);
		    $start = $start + @x;
		}
		$seq =~ s/N+$//;
		@x = split(//,$seq);
		$seqlength = @x;
		$end = $start + $seqlength - 1; 
	    }
	    $a_reads{"$id\t$strand\t$chr\t$start\t$end\t$seq"}++;
	    if($a_reads{"$id\t$strand\t$chr\t$start\t$end\t$seq"} == 1) {
		$num_different_a++;
	    }
	}
	$num_different_b = 0;
	for($i=0; $i<$numb; $i++) {
	    $line2 = $seqs_b[$i];
	    if(!($line2 =~ /^N+$/)) {
		@a = split(/\t/,$line2);
		$id = $a[0];
		$strand = $a[1];
		$chr = $a[2];
		$chr =~ s/:.*//;
		$start = $a[3]+1;
		$seq = $a[4];
		if($seq =~ /^(N+)/) {
		    $seq =~ s/^(N+)//;
		    $Nprefix = $1;
		    @x = split(//,$Nprefix);
		    $start = $start + @x;
		}
		$seq =~ s/N+$//;
		@x = split(//,$seq);
		$seqlength = @x;
		$end = $start + $seqlength - 1; 
	    }
	    $b_reads{"$id\t$strand\t$chr\t$start\t$end\t$seq"}++;
	    if($b_reads{"$id\t$strand\t$chr\t$start\t$end\t$seq"} == 1) {
		$num_different_b++;
	    }
	}
    }
# NOTE: the following three if's cover all cases we care about, because if numa > 1 and numb = 0, then that's
# not really ambiguous, blat might resolve it

    if($num_different_a == 1 && $num_different_b == 0) { # unique forward match, no reverse
	foreach $key (keys %a_reads) {
	    $key =~ /^[^\t]+\t(.)\t/;
	    $strand = $1;
	    $key =~ s/\t\+//;
	    $key =~ s/\t-//;
	    $key =~ /^[^\t]+\t[^\t]+\t([^\t]+\t[^\t]+)\t/;
	    $xx = $1;
	    $yy = $xx;
	    $xx =~ s/\t/-/;  # this puts the dash between the start and end
	    $key =~ s/$yy/$xx/;
	    print OUTFILE1 "$key\t$strand\n";
	}
    }
    if($num_different_a == 0 && $num_different_b == 1) { # unique reverse match, no forward
	foreach $key (keys %b_reads) {
	    $key =~ /^[^\t]+\t(.)\t/;
	    $strand = $1;
	    if($strand eq "+") {  # got to reverse this because it's the reverse read,
                                  # because we are reporting strand of forward in all cases
		$strand = "-";
	    } else {
		$strand = "+";
	    }
	    $key =~ s/\t\+//;
	    $key =~ s/\t-//;
	    $key =~ /^[^\t]+\t[^\t]+\t([^\t]+\t[^\t]+)\t/;
	    $xx = $1;
	    $yy = $xx;
	    $xx =~ s/\t/-/;  # this puts the dash between the start and end
	    $key =~ s/$yy/$xx/;
	    print OUTFILE1 "$key\t$strand\n";
	}
    }
    if($paired_end eq "false") {
	if($num_different_a > 1) { 
	    foreach $key (keys %a_reads) {
		$key =~ /^[^\t]+\t(.)\t/;
		$strand = $1;
		$key =~ s/\t\+//;
		$key =~ s/\t-//;
		$key =~ /^[^\t]+\t[^\t]+\t([^\t]+\t[^\t]+)\t/;
		$xx = $1;
		$yy = $xx;
		$xx =~ s/\t/-/;  # this puts the dash between the start and end
		$key =~ s/$yy/$xx/;
		print OUTFILE2 "$key\t$strand\n";
	    }
	}
    }
    if(($num_different_a > 0 && $num_different_b > 0) && ($num_different_a * $num_different_b < 1000000)) { 
# forward and reverse matches, must check for consistency, but not if more than 1,000,000 possibilities,
# in that case skip...
	undef %consistent_mappers;
	foreach $akey (keys %a_reads) {
	    foreach $bkey (keys %b_reads) {

		@a = split(/\t/,$akey);
		$aid = $a[0];
		$astrand = $a[1];
		$achr = $a[2];
		$astart = $a[3];
		$aend = $a[4];
		$aseq = $a[5];
		@a = split(/\t/,$bkey);
		$bstrand = $a[1];
		$bchr = $a[2];
		$bstart = $a[3];
		$bend = $a[4];
		$bseq = $a[5];
		if($astrand eq "+" && $bstrand eq "-") {
		    if($achr eq $bchr && $astart <= $bstart && $bstart - $astart < $max_distance_between_paired_reads) {
			if($bstart > $aend + 1) {
			    $akey =~ s/\t\+//;
			    $akey =~ s/\t-//;
			    $bkey =~ s/\t\+//;
			    $bkey =~ s/\t-//;
			    $akey =~ /^[^\t]+\t[^\t]+\t([^\t]+\t[^\t]+)\t/;
			    $xx = $1;
			    $yy = $xx;
			    $xx =~ s/\t/-/;
			    $akey =~ s/$yy/$xx/;
			    $bkey =~ /^[^\t]+\t[^\t]+\t([^\t]+\t[^\t]+)\t/;
			    $xx = $1;
			    $yy = $xx;
			    $xx =~ s/\t/-/;
			    $bkey =~ s/$yy/$xx/;
			    $consistent_mappers{"$akey\t$astrand\n$bkey\t$astrand\n"}++;
			}
			else {
			    $overlap = $aend - $bstart + 1;
			    @sq = split(//,$bseq);
			    $joined_seq = $aseq;
			    for($i=$overlap; $i<@sq; $i++) {
				$joined_seq = $joined_seq . $sq[$i];
			    }
			    $aid =~ s/a//;
			    $consistent_mappers{"$aid\t$achr\t$astart-$bend\t$joined_seq\t$astrand\n"}++;
			}
		    }
		}
		if($astrand eq "-" && $bstrand eq "+") {
		    if($achr eq $bchr && $bstart <= $astart && $astart - $bstart < $max_distance_between_paired_reads) {
			if($astart > $bend + 1) {
			    $akey =~ s/\t\+//;
			    $akey =~ s/\t-//;
			    $bkey =~ s/\t\+//;
			    $bkey =~ s/\t-//;
			    $akey =~ /^[^\t]+\t[^\t]+\t([^\t]+\t[^\t]+)\t/;
			    $xx = $1;
			    $yy = $xx;
			    $xx =~ s/\t/-/;
			    $akey =~ s/$yy/$xx/;
			    $bkey =~ /^[^\t]+\t[^\t]+\t([^\t]+\t[^\t]+)\t/;
			    $xx = $1;
			    $yy = $xx;
			    $xx =~ s/\t/-/;
			    $bkey =~ s/$yy/$xx/;
			    $consistent_mappers{"$akey\t$astrand\n$bkey\t$astrand\n"}++;
			}
			else {
			    $overlap = $bend - $astart + 1;
			    @sq = split(//,$bseq);
			    $joined_seq = "";
			    for($i=0; $i<@sq-$overlap; $i++) {
				$joined_seq = $joined_seq . $sq[$i];
			    }
			    $joined_seq = $joined_seq . $aseq;
			    $aid =~ s/a//;
			    $consistent_mappers{"$aid\t$achr\t$bstart-$aend\t$joined_seq\t$astrand\n"}++;
			}
		    }
		}
	    }
	}
	$count = 0;
	foreach $key (keys %consistent_mappers) {
	    $count++;
	    $str = $key;
	}
	if($count == 1) {
	    print OUTFILE1 $str;
	}
	if($count > 1) {
# add something here so that if all consistent mappers agree on some
# exons, then those exons will still get reported, each on its own line
	    foreach $key (keys %consistent_mappers) {
		print OUTFILE2 $key;
	    }
	}
    }
}
close(OUTFILE1);
close(OUTFILE2);
