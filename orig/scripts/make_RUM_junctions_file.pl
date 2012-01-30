#!/usr/bin/perl

# Written by Gregory R. Grant
# University of Pennsylvania, 2010

# Splice Junctions:
# ----------------
# The Canonical:
#  GTAG
$donor[0] = "GT";
$donor_rev[0] = "AC";
$acceptor[0] = "AG";
$acceptor_rev[0] = "CT";
# Other Characterized:
#  GCAG
$donor[1] = "GC";
$donor_rev[1] = "GC";
$acceptor[1] = "AG";
$acceptor_rev[1] = "CT";
#  GCTG
$donor[2] = "GC";
$donor_rev[2] = "GC";
$acceptor[2] = "TG";
$acceptor_rev[2] = "CA";
#  GCAA
$donor[3] = "GC";
$donor_rev[3] = "GC";
$acceptor[3] = "AA";
$acceptor_rev[3] = "TT";
#  GCCG
$donor[4] = "GC";
$donor_rev[4] = "GC";
$acceptor[4] = "CG";
$acceptor_rev[4] = "CG";
#  GTTG
$donor[5] = "GT";
$donor_rev[5] = "AC";
$acceptor[5] = "TG";
$acceptor_rev[5] = "CA";
#  GTAA
$donor[6] = "GT";
$donor_rev[6] = "AC";
$acceptor[6] = "AA";
$acceptor_rev[6] = "TT";
# U12-dependent:
#  ATAC
$donor[7] = "AT";
$donor_rev[7] = "AT";
$acceptor[7] = "AC";
$acceptor_rev[7] = "GT";
#  ATAA
$donor[8] = "AT";
$donor_rev[8] = "AT";
$acceptor[8] = "AA";
$acceptor_rev[8] = "TT";
#  ATAG
$donor[9] = "AT";
$donor_rev[9] = "AT";
$acceptor[9] = "AG";
$acceptor_rev[9] = "CT";
#  ATAT
$donor[10] = "AT";
$donor_rev[10] = "AT";
$acceptor[10] = "AT";
$acceptor_rev[10] = "AT";

$|=1;

if(@ARGV < 7) {
    die "

Usage: make_RUM_junctions_file.pl <rum_unique> <rum_nu> <genome seq> <gene annotations> <all junctions outfile rum-format> <all junctions outfile bed-format> <high quality junctions outfile bed-format> [options]

Where:
   <gene annotations> is the RUM gene models file, put 'none' if there are no known gene models.

Options:
   -faok  : the fasta file already has sequence all on one line

   -minintron n : the size of the smallest intron allowed 0<n (default = 15 bp)

   -overlap n : there must be at least this many bases spanning either side of a junction
                to qualify as high quality (default = 8 bp)

   -signal wxyz : Use this alternate splice signal, wx is the donor and yz the acceptor.
                  Multiple may be specified, separated by commas w/o whitespace.  If not
                  specified, the standard signals will be used, with the canonical colored
                  darker in the high quality junctions file.

This script finds the junctions in the RUM_Unique and RUM_NU files
and reports them to a junctions file that can be uploaded to the UCSC
browser.

In the high quality junctions, junctions in the annotation file are colored blue,
others are colored green.  Those with standard splice signals (or those
specified by -signal) are colored a shade lighter.

";
}

print STDERR "\nMaking junctions files...\n";

$allowable_overlap = 8;
$rumU = $ARGV[0];
$rumNU = $ARGV[1];
$genome_sequence = $ARGV[2];
$gene_annot = $ARGV[3];
$outfile1 = $ARGV[4];
$outfile2 = $ARGV[5];
$outfile3 = $ARGV[6];

open(OUTFILE1, ">$outfile1") or die "\nError: cannot open file '$outfile1' for writing\n\n";
print OUTFILE1 "intron\tscore\tknown\tstandard_splice_signal\tsignal_not_canonical\tambiguous\tlong_overlap_unique_reads\tshort_overlap_unique_reads\tlong_overlap_nu_reads\tshort_overlap_nu_reads\n";

open(OUTFILE2, ">$outfile2") or die "\nError: cannot open file '$outfile2' for writing\n\n";
print OUTFILE2 "track\tname=rum_junctions_all\tvisibility=3\tdescription=\"RUM junctions (all)\" itemRgb=\"On\"\n";

open(OUTFILE3, ">$outfile3") or die "\nError: cannot open file '$outfile3' for writing\n\n";
print OUTFILE3 "track\tname=rum_junctions_hq\tvisibility=3\tdescription=\"RUM high quality junctions\" itemRgb=\"On\"\n";

# read in known junctions to color them green in the hq track:

if($gene_annot ne "none") {
    open(INFILE, $gene_annot) or die "\nError: cannot open file '$gene_annot' for reading\n\n";
    while($line = <INFILE>) {
	@a = split(/\t/, $line);
	$chr = $a[0];
	$a[5] =~ s/\s*,\s*$//;
	$a[6] =~ s/\s*,\s*$//;
	$a[5] =~ s/^\s*,\s*//;
	$a[6] =~ s/^\s*,\s*//;
	@starts = split(/\s*,\s*/,$a[5]);
	@ends = split(/\s*,\s*/,$a[6]);
	for($i=0; $i<@starts-1; $i++) {
	    $S = $ends[$i] + 1;
	    $E = $starts[$i+1];
	    $intron = $chr . ":" . $S . "-" . $E;
	    $knownintron{$intron} = 1;
	}
    }
    close(INFILE);
}

$faok = "false";
$minintron = 15;
for($i=7; $i<@ARGV; $i++) {
    $optionrecognized = 0;
    if($ARGV[$i] eq "-signal") {
	$i++;
	@AR = split(/,/,$ARGV[$i]);
	undef @donor;
	undef @donor_rev;
	undef @acceptor;
	undef @acceptor_rev;
	for($j=0; $j<@AR; $j++) {
	    if($AR[$j] =~ /^([ACGT][ACGT])([ACGT][ACGT])$/) {
		$donor[$j] = $1;
		$acceptor[$j] = $2;
		$donor_rev[$j] = reversesignal($donor[$j]);
		$acceptor_rev[$j] = reversesignal($acceptor[$j]);
	    } else {
		die "\nError: the -signal argument is misformatted, check signal $i: '$AR[$j]'\n\n";
	    }
	}
	$optionrecognized = 1;
    }    
    if($ARGV[$i] eq "-faok") {
	$faok = "true";
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-minintron") {
	$minintron = $ARGV[$i+1];
	if(!($minintron =~ /^\d+$/)) {
	    die "\nError: -minintron must be an integer greater than zero, you gave '$minintron'.\n\n";
	} elsif($minintron==0) {
	    die "\nError: -minintron must be an integer greater than zero, you gave '$minintron'.\n\n";
	}
	$i++;
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-overlap") {
	$allowable_overlap = $ARGV[$i+1];
	if(!($allowable_overlap =~ /^\d+$/)) {
	    die "\nError: -overlap must be an integer greater than zero, you gave '$allowable_overlap'.\n\n";
	} elsif($allowable_overlap==0) {
	    die "\nError: -overlap must be an integer greater than zero, you gave '$allowable_overlap'.\n\n";
	}
	$i++;
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
    `perl modify_fa_to_have_seq_on_one_line.pl $genome_sequence > $f`;
    open(GENOMESEQ, $f) or die "\nError: cannot open file '$f' for reading\n\n";
} else {
    open(GENOMESEQ, $genome_sequence) or die "\nError: cannot open file '$genome_sequence' for reading\n\n";
}

# DEBUG
# for($i=0; $i<@donor; $i++) {
#     print "donor[$i] = $donor[$i]\n";
#     print "donor_rev[$i] = $donor_rev[$i]\n";
# }
# for($i=0; $i<@acceptor; $i++) {
#     print "acceptor[$i] = $acceptor[$i]\n";
#     print "acceptor_rev[$i] = $acceptor_rev[$i]\n";
# }
# exit();
# DEBUG

$FLAG = 0;
while($FLAG == 0) {
    undef %CHR2SEQ;
    undef %allintrons;
    undef @amb;
    undef @badoverlapU;
    undef @goodoverlapU;
    undef @badoverlapNU;
    undef @goodoverlapNU;

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
	    print STDERR "chr=$chr\n";
	    $ref_seq = <GENOMESEQ>;
	    chomp($ref_seq);
	    $CHR2SEQ{$chr} = $ref_seq;
	    $CHR2SIZE{$chr} = length($ref_seq);
	    $totalsize = $totalsize + $CHR2SIZE{$chr};
	    if($totalsize > 1000000000) {  # don't store more than 1 gb of sequence in memory at once...
		$sizeflag = 1;
	    }
	}
    }
    &getjunctions();
    &printjunctions();
}
close(GENOMESEQ);

sub printjunctions () {
    foreach $intron (keys %allintrons) {
	$amb{$intron} = $amb{$intron} + 0;
	$badoverlapU{$intron} = $badoverlapU{$intron} + 0;
	$goodoverlapU{$intron} = $goodoverlapU{$intron} + 0;
	$badoverlapNU{$intron} = $badoverlapNU{$intron} + 0;
	$goodoverlapNU{$intron} = $goodoverlapNU{$intron} + 0;
	$knownintron{$intron} = $knownintron{$intron} + 0;

# chromosome
# start seg 1: 50 bases upstream from junction start
# start seg 2: 50 bases upstream from junction end
# score: goodoverlap_badoverlap
# 50
# +
# start seg 1: 50 bases upstream from junction start (again)
# start seg 2: 50 bases upstream from junction end (again)
# 
# Color:
#    0,0,128 NAVY (for high quality)
#    255,69,0 RED (for low quality)
# 2
# 50,50
# 0, intron_length + 50
 
	$intron =~ /^(.*):(\d+)-(\d+)$/;
	$chr = $1;
	$start = $2 - 1;
	$end = $3;
	$end2 = $end + 50;
	$start2 = $start - 50;
	$ilen = $end - $start + 50;
	$LEN1 = 50;
	$LEN2 = 50;
	if($start2 < 0) {
	    $adjust = $start2;
	    $start2 = 0;
	    $LEN1 = $LEN1 + $adjust;
	    $ilen = $ilen + $adjust;
	}
	if($end2 >= $CHR2SIZE{$chr}) {
	    $adjust = $end2 - $CHR2SIZE{$chr} + 1;
	    $end2 = $end2 - $adjust;
	    $LEN2 = $LEN2 - $adjust;
	}
	if($goodsplicesignal{$intron} > 0) {
	    $goodsplicesignal{$intron} = 1;
	}
	$known_noncanonical_signal{$intron} = $known_noncanonical_signal{$intron} + 0;
	if($goodoverlapU{$intron} > 0 && $goodsplicesignal{$intron} == 1) {
	    $N = $goodoverlapU{$intron} + $goodsplicesignal{$intron} - 1;
	    print OUTFILE1 "$intron\t$N\t$knownintron{$intron}\t$goodsplicesignal{$intron}\t$known_noncanonical_signal{$intron}\t$amb{$intron}\t$goodoverlapU{$intron}\t$badoverlapU{$intron}\t$goodoverlapNU{$intron}\t$badoverlapNU{$intron}\n";
	    print OUTFILE2 "$chr\t$start2\t$end2\t$N\t$N\t+\t$start2\t$end2\t0,0,128\t2\t$LEN1,$LEN2\t0,$ilen\n";
	    if($knownintron{$intron}==1) {
		if($known_noncanonical_signal{$intron}+0==1) {
		    print OUTFILE3 "$chr\t$start2\t$end2\t$N\t$N\t+\t$start2\t$end2\t24,116,205\t2\t$LEN1,$LEN2\t0,$ilen\n";
		} else {
		    print OUTFILE3 "$chr\t$start2\t$end2\t$N\t$N\t+\t$start2\t$end2\t16,78,139\t2\t$LEN1,$LEN2\t0,$ilen\n";
		}
	    } else {
		if($known_noncanonical_signal{$intron}+0==1) {
		    print OUTFILE3 "$chr\t$start2\t$end2\t$N\t$N\t+\t$start2\t$end2\t0,255,127\t2\t$LEN1,$LEN2\t0,$ilen\n";
		} else {
		    print OUTFILE3 "$chr\t$start2\t$end2\t$N\t$N\t+\t$start2\t$end2\t0,205,102\t2\t$LEN1,$LEN2\t0,$ilen\n";
		}
	    }
	} else {
	    print OUTFILE1 "$intron\t0\t$knownintron{$intron}\t$goodsplicesignal{$intron}\t$known_noncanonical_signal{$intron}\t$amb{$intron}\t$goodoverlapU{$intron}\t$badoverlapU{$intron}\t$goodoverlapNU{$intron}\t$badoverlapNU{$intron}\n";
	    $NN = $goodoverlapU{$intron} + $goodoverlapNU{$intron} + $badoverlapU{$intron} + $badoverlapNU{$intron};
	    print OUTFILE2 "$chr\t$start2\t$end2\t$NN\t$NN\t+\t$start2\t$end2\t255,69,0\t2\t$LEN1,$LEN2\t0,$ilen\n";
	}
    }
}

# chr2    181747872       181748112       0       0       +       181747872       181748112       255,69,0    50,50    0,190
# 181748087


sub getjunctions () {
    open(INFILE, $rumU) or die "\nError: cannot open file '$rumU' for reading\n\n";
    print STDERR "please wait...\n";
    while($line = <INFILE>) {
	if(!($line =~ /, /)) {
	    next;
	}
	chomp($line);
	@a = split(/\t/,$line);
	$chr = $a[1];
	if(!(defined $CHR2SEQ{$chr})) {
	    next;
	}
	$seq = $a[4];
	$snt = $a[0];
	$snt =~ s/seq.//;
#	print STDERR "1:seq.$snt\n";
	while($seq =~ /^([^+]*)\+/) {  # removing the insertions
	    $pref = $1;
	    $seq =~ s/^$pref\+[^+]+\+/$pref/;
	}
	$strand = $a[3];
	@SPANS = split(/, /,$a[2]);
	@SEQ = split(/:/, $seq);
	for($i=0; $i<@SPANS-1; $i++) {
	    @c1 = split(/-/,$SPANS[$i]);
	    @c2 = split(/-/,$SPANS[$i+1]);
	    $elen1 = $c1[1] - $c1[0] + 1;
	    $elen2 = $c2[1] - $c2[0] + 1;
	    $ilen = $c2[0] - $c1[1] - 1;
	    $istart = $c1[1]+1;
	    $iend = $c2[0]-1;
	    $intron = $chr . ":" . $istart . "-" . $iend;
	    $altintron = "";
	    if($ilen >= $minintron) {
		$allintrons{$intron} = 1;
		if(!(defined $amb{$intron}) || !($goodsplicesignal{$intron})) {
		    $SEQ[$i] =~ /(.)$/;
		    $leftexon_lastbase = $1;
		    $SEQ[$i+1] =~ /^(.)/;
		    $rightexon_firstbase = $1;
		    $intron_firstbase = substr($CHR2SEQ{$chr}, $istart-1, 1);
		    $intron_lastbase = substr($CHR2SEQ{$chr}, $iend-1, 1);
		    $splice_signal_upstream = substr($CHR2SEQ{$chr}, $istart-1, 2);
		    $splice_signal_downstream = substr($CHR2SEQ{$chr}, $iend-2, 2);
		    for($sig=0; $sig<@donor; $sig++) {
			if(($splice_signal_upstream eq $donor[$sig] && $splice_signal_downstream eq $acceptor[$sig]) || ($splice_signal_upstream eq $acceptor_rev[$sig] && $splice_signal_downstream eq $donor_rev[$sig])) {
			    $goodsplicesignal{$intron} = $goodsplicesignal{$intron} + 1;
			    if($sig>0) {
				$known_noncanonical_signal{$intron} = 1;
			    }
			} else {
			    $goodsplicesignal{$intron} = $goodsplicesignal{$intron} + 0;
			}
		    }
		    if($leftexon_lastbase eq $intron_lastbase) {
			$istart_alt = $istart-1;
			$iend_alt = $iend-1;
			$altintron = $chr . ":" . $istart_alt . "-" . $iend_alt;
			$amb{$intron}=1;  # amb for ambiguous
			$amb{$altintron}=1;
			$allintrons{$altintron} = 1;
		    }
		    if($rightexon_firstbase eq $intron_firstbase) {
			$istart_alt = $istart+1;
			$iend_alt = $iend+1;
			$altintron = $chr . ":" . $istart_alt . "-" . $iend_alt;
			$amb{$intron}=1;  # amb for ambiguous
			$amb{$altintron}=1;
			$allintrons{$altintron} = 1;
		    }
		}
		if($elen1 <= $allowable_overlap || $elen2 <= $allowable_overlap) {
		    $badoverlapU{$intron}++;
		    if($altintron =~ /\S/) {
			$badoverlapU{$altintron}++;			    
		    }
		} else {
		    $goodoverlapU{$intron}++;
		    if($altintron =~ /\S/) {
			$goodoverlapU{$altintron}++;			    
		    }
		}
	    }
	}
    }
    close(INFILE);
#    print STDERR "finished Unique\n";
    print STDERR "please wait some more...\n";
    open(INFILE, $rumNU) or die "\nError: cannot open file '$rumNU' for reading\n\n";
    while($line = <INFILE>) {
	if(!($line =~ /, /)) {
	    next;
	}
	chomp($line);
	@a = split(/\t/,$line);
	if(!(defined $CHR2SEQ{$a[1]})) {
	    next;
	}
	$seq = $a[4];
	while($seq =~ /^([^+]*)\+/) {  # removing the insertions
	    $pref = $1;
	    $seq =~ s/^$pref\+[^+]+\+/$pref/;
	}
	$strand = $a[3];
	$chr = $a[1];
	@SPANS = split(/, /,$a[2]);
	@SEQ = split(/:/, $seq);
	$snt = $a[0];
	$snt =~ s/seq.//;
#	print STDERR "2:seq.$snt\n";
	for($i=0; $i<@SPANS-1; $i++) {
	    @c1 = split(/-/,$SPANS[$i]);
	    @c2 = split(/-/,$SPANS[$i+1]);
	    $elen1 = $c1[1] - $c1[0] + 1;
	    $elen2 = $c2[1] - $c2[0] + 1;
	    $ilen = $c2[0] - $c1[1] - 1;
	    $istart = $c1[1]+1;
	    $iend = $c2[0]-1;
	    $altintron="";
	    if($ilen >= $minintron) {
		$intron = $chr . ":" . $istart . "-" . $iend;
		$allintrons{$intron} = 1;
		if(!(defined $amb{$intron})) {
		    $SEQ[$i] =~ /(.)$/;
		    $leftexon_lastbase = $1;
		    $SEQ[$i+1] =~ /^(.)/;
		    $rightexon_firstbase = $1;
		    $intron_firstbase = substr($CHR2SEQ{$chr}, $istart-1, 1);
		    $intron_lastbase = substr($CHR2SEQ{$chr}, $iend-1, 1);
		    $splice_signal_upstream = substr($CHR2SEQ{$chr}, $istart-1, 2);
		    $splice_signal_downstream = substr($CHR2SEQ{$chr}, $iend-2, 2);
		    for($sig=0; $sig<@donor; $sig++) {
			if(($splice_signal_upstream eq $donor[$sig] && $splice_signal_downstream eq $acceptor[$sig]) || ($splice_signal_upstream eq $acceptor_rev[$sig] && $splice_signal_downstream eq $donor_rev[$sig])) {
			    $goodsplicesignal{$intron} = $goodsplicesignal{$intron} + 1;
			    $known_noncanonical_signal{$intron} = 1;
			} else {
			    $goodsplicesignal{$intron} = $goodsplicesignal{$intron} + 0;
			}
		    }
		    if($leftexon_lastbase eq $intron_lastbase) {
			$istart_alt = $istart-1;
			$iend_alt = $iend-1;
			$altintron = $chr . ":" . $istart_alt . "-" . $iend_alt;
			$amb{$intron}=1;  # amb for ambiguous
			$amb{$altintron}=1;
			$allintrons{$intron} = 1;
		    }
		    if($rightexon_firstbase eq $intron_firstbase) {
			$istart_alt = $istart+1;
			$iend_alt = $iend+1;
			$altintron = $chr . ":" . $istart_alt . "-" . $iend_alt;
			$amb{$intron}=1;  # amb for ambiguous
			$amb{$altintron}=1;
			$allintrons{$intron} = 1;
		    }
		}
#		    print "elen1 = $elen1\n";
#		    print "elen2 = $elen2\n";
		if($elen1 <=$allowable_overlap || $elen2 <= $allowable_overlap) {
		    $badoverlapNU{$intron}++;
		    if($altintron =~ /\S/) {
			$badoverlapNU{$altintron}++;			    
		    }
		} else {
		    $goodoverlapNU{$intron}++;
		    if($altintron =~ /\S/) {
			$goodoverlapNU{$altintron}++;			    
		    }
		}
	    }
	}
    }
    close(INFILE);
#    print STDERR "finished NU\n";
}

sub reversesignal () {
    ($IT) = @_;
    $IT =~ /(.)(.)/;
    $base_r[0] = $1;
    $base_r[1] = $2;
    $return_string = "";
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
