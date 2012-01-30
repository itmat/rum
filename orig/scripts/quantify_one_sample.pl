#!/usr/bin/perl

$|=1;
if(@ARGV < 2) {
    print "\n----------------------------------------------------------------------------------------------------------\n";
    print "Usage: quantify_one_sample.pl <cov file> <gene annotation file> [options]\n\n";
    print "Options:  -zero : .cov file is zero-based (default: one-based)\n";
    print "          -open : .cov file is half-open (i.e. does not contain right endpoint of span) (default: not half open)\n";
    print "          -annot_one : annot file is one-based (default: zero-based)\n";
    print "          -annot_closed : annot file is half-closed (i.e. does contain right endpoint of span) (default: half-open)\n";
    print "Note: UCSC browser custom tracks are required to be zero-based half-open.\n\n";
    print "Expecting gene annotation file with following eight columns:\n";
    print "> chr   strand   start    end   num_exons   exon_starts   exon_ends   gene_ids (ucsc and refseq).\n";
    print "For example the following:\n";
    print "> chr3    -       88198064        88214238        5       88198064,88199826,88203056,88203632,88214077,   88198492,88200022,88203157,88203738,88214238,       uc008pva.1(ucscgenes)::::NM_025928(refseq)\n";
    print "\nAssume the annotation file sorted by chr, chr_start, chr_end.\n";
    print "\nResults output with one-based half-closed coordinates\n";
    print "----------------------------------------------------------------------------------------------------------\n";
    exit(0);
}

$zerobased = "false";
$open = "false";
$annot_zerobased = "true";
$annot_open = "true";
for($i=2; $i<@ARGV; $i++) {
    $optionrecognized = 0;
    if($ARGV[$i] eq "-zero") {
	$zerobased = "true";
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-open") {
	$open = "true";
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-annot_one") {
	$annot_zerobased = "false";
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-annot_closed") {
	$annot_open = "false";
	$optionrecognized = 1;
    }
    if($optionrecognized == 0) {
	print STDERR "\nError: option \'$ARGV[$i]\' is not recognized\n\n";
	exit(0);
    }
}

# changing all coords of annotation file to be one based half closed
open(INFILE, $ARGV[1]);
while($line = <INFILE>) {
    chomp($line);
    @a = split(/\t/,$line);
    $chr = $a[0];
    $genenum{$chr} = $genenum{$chr} + 0;
    $gene_start{$chr}[$genenum{$chr}] = $a[2];
    $gene_end{$chr}[$genenum{$chr}] = $a[3];
    if($annot_zerobased eq "true") {
	$gene_start{$chr}[$genenum{$chr}]++;
	$gene_end{$chr}[$genenum{$chr}]++;
    }
    if($annot_open eq "true") {
	$gene_end{$chr}[$genenum{$chr}]--;
    }
    $numexons{$chr}[$genenum{$chr}] = $a[4];
    $numintrons{$chr}[$genenum{$chr}] = $a[4] - 1;
    $strand{$chr}[$genenum{$chr}] = $a[1];
    @b = split(/,/,$a[5]);
    @c = split(/,/,$a[6]);
    for($i=0;$i<$numexons{$chr}[$genenum{$chr}];$i++) {
	$exonstart{$chr}[$genenum{$chr}][$i] = $b[$i];
	$exonend{$chr}[$genenum{$chr}][$i] = $c[$i];
	if($annot_zerobased eq "true") {
	    $exonstart{$chr}[$genenum{$chr}][$i]++;
	    $exonend{$chr}[$genenum{$chr}][$i]++;
	}
	if($annot_open eq "true") {
	    $exonend{$chr}[$genenum{$chr}][$i]--;
	}	
    }
    for($i=0;$i<$numintrons{$chr}[$genenum{$chr}];$i++) {
	$intronstart{$chr}[$genenum{$chr}][$i] = $exonend{$chr}[$genenum{$chr}][$i] + 1;
	$intronend{$chr}[$genenum{$chr}][$i] = $exonstart{$chr}[$genenum{$chr}][$i+1] - 1;
    }
    $geneid{$chr}[$genenum{$chr}] = $a[7];
    $genenum{$chr}++;
}
close(INFILE);

open(INFILE, $ARGV[0]);
foreach $chr (keys %genenum) {
    $start{$chr} = 0;
}
$genecounter=0;
$line = <INFILE>;
$flag = 0;
$skip = 0;
while($flag == 0) {
    $flag = 1;
    @a = split(/\t/,$line);
    if(@a > 4 || !($a[1] =~ /^\d+$/) || !($a[2] =~ /^\d+$/) || !($a[3] =~ /^\d*\.?\d*$/)) {
	$flag = 0;
	$skip++;
    }
    $line = <INFILE>;
}
$basereads_total = 0;
while($line = <INFILE>) {
    chomp($line);
    @a = split(/\t/,$line);
    $basereads_total = $basereads_total + $a[3] * ($a[2] - $a[1]);
}
$coverage_normalization_factor = $basereads_total / 1000000000;
close(INFILE);
open(INFILE, $ARGV[0]);
for($i=0; $i<$skip; $i++) {
    $line = <INFILE>;
}
print "basereads_total= $basereads_total\n";
print STDERR "Quantifying ...\n";
#print STDERR "skipping $skip line(s) of header\n";
while($line = <INFILE>) {
    chomp($line);
    @a = split(/\t/,$line);
    $chr = $a[0];
    $span_start = $a[1];
    $span_end = $a[2];
    if($zerobased eq "true") {
	$span_start++;
	$span_end++;
    }
    if($open eq "true") {
	$span_end--;
    }
    $count = $a[3];
    $genecounter = $start{$chr};
    while($gene_start{$chr}[$genecounter] <= $span_end) {
	for($exon=0; $exon<$numexons{$chr}[$genecounter]; $exon++) {
	    if($exonstart{$chr}[$genecounter][$exon] <= $span_end && $exonend{$chr}[$genecounter][$exon] >= $span_start) {
		if($exonstart{$chr}[$genecounter][$exon] <= $span_start && $exonend{$chr}[$genecounter][$exon] >= $span_end) {
		    $overlap = $span_end - $span_start + 1;
		}
		if($exonstart{$chr}[$genecounter][$exon] > $span_start && $exonend{$chr}[$genecounter][$exon] >= $span_end) {
		    $overlap = $span_end - $exonstart{$chr}[$genecounter][$exon] + 1;
		}
		if($exonstart{$chr}[$genecounter][$exon] <= $span_start && $exonend{$chr}[$genecounter][$exon] < $span_end) {
		    $overlap =  $exonend{$chr}[$genecounter][$exon] - $span_start + 1;
		}
		if($overlap < 0) {
		    print STDERR "\nWARNING: Something is wrong, I came up with a negative overlap\nbetween a read and an exon.  Perhaps your coverage file\ndoes not conform to your parameters regarding zero/one based and half open/closed.\n";
		    exit(0);
		}
		$exon_count{$chr}[$genecounter][$exon] = $exon_count{$chr}[$genecounter][$exon] + $overlap * $count;
	    }
	}
	for($intron=0; $intron<$numintrons{$chr}[$genecounter]; $intron++) {
	    if($intronstart{$chr}[$genecounter][$intron] <= $span_end && $intronend{$chr}[$genecounter][$intron] >= $span_start) {
		if($intronstart{$chr}[$genecounter][$intron] <= $span_start && $intronend{$chr}[$genecounter][$intron] >= $span_end) {
		    $overlap = $span_end - $span_start + 1;
		}
		if($intronstart{$chr}[$genecounter][$intron] > $span_start && $intronend{$chr}[$genecounter][$intron] >= $span_end) {
		    $overlap = $span_end - $intronstart{$chr}[$genecounter][$intron] + 1;
		}
		if($intronstart{$chr}[$genecounter][$intron] <= $span_start && $intronend{$chr}[$genecounter][$intron] < $span_end) {
		    $overlap =  $intronend{$chr}[$genecounter][$intron] - $span_start + 1;
		}
		if($overlap < 0) {
		    print STDERR "\nWARNING: Something is wrong, I came up with a negative overlap\nbetween a read and an exon.  Perhaps your coverage file\ndoes not conform to your parameters regarding zero/one based and half open/closed.\n";
		    exit(0);
		}
		$intron_count{$chr}[$genecounter][$intron] = $intron_count{$chr}[$genecounter][$intron] + $overlap * $count;
	    }
	}
	$genecounter++;
	if($genecounter >= $genenum{$chr}) {
	    last;
	}
    }
    if($gene_end{$chr}[$start{$chr}] < $span_start) {
	$start{$chr}++;
    }
}
foreach $chr (keys %geneid) {
    for($gc=0; $gc<$genenum{$chr}; $gc++) {
	print "--------------------------------------------------------------------\n";
	print "$geneid{$chr}[$gc]\t$strand{$chr}[$gc]\n";
	print "    Type\tLocation          \tCount\tAve_Cnt\tAve_Nrm\tLength\n";
	print "    gene\t$chr:$gene_start{$chr}[$gc]-$gene_end{$chr}[$gc]";
	$gene_count = 0;
	$gene_length = 0;
	$string = "";
	for($i=0; $i<$numexons{$chr}[$gc]; $i++) {
	    $exon_count{$chr}[$gc][$i] = $exon_count{$chr}[$gc][$i] + 0;
	    $j=$i+1;
	    $exon_length = $exonend{$chr}[$gc][$i] - $exonstart{$chr}[$gc][$i] + 1;
	    if($exon_length > 0) {
		$ave = $exon_count{$chr}[$gc][$i] / $exon_length;
	    }
	    else {
		$ave = 0;
	    }
	    $ave = int(100000 * $ave) / 100000;
	    $ave_norm = $ave / $coverage_normalization_factor;
	    $ave_norm = int(10000 * $ave_norm) / 10000;
	    $gene_count = $gene_count + $exon_count{$chr}[$gc][$i];
	    $gene_length = $gene_length + $exon_length;
	    if($strand{$chr}[$gc] eq "+") {
		$string = $string . "  exon $j\t$chr:$exonstart{$chr}[$gc][$i]-$exonend{$chr}[$gc][$i]\t$exon_count{$chr}[$gc][$i]\t$ave\t$ave_norm\t$exon_length\n";
	    }
	    else {
		$k = $numexons{$chr}[$gc] - $j + 1;
		$string = "  exon $k\t$chr:$exonstart{$chr}[$gc][$i]-$exonend{$chr}[$gc][$i]\t$exon_count{$chr}[$gc][$i]\t$ave\t$ave_norm\t$exon_length\n" . $string;
	    }
	    if($i < $numintrons{$chr}[$gc]) {
		$intron_count{$chr}[$gc][$i] = $intron_count{$chr}[$gc][$i] + 0;
		$intron_length = $intronend{$chr}[$gc][$i] - $intronstart{$chr}[$gc][$i] + 1;
		if($intron_length > 0) {
		    $ave = $intron_count{$chr}[$gc][$i] / $intron_length;
		}
		else {
		    $ave = 0;
		}
		$ave = int(10000 * $ave) / 10000;
		$ave_norm = $ave / $coverage_normalization_factor;
		$ave_norm = int(10000 * $ave_norm) / 10000;
		if($strand{$chr}[$gc] eq "+") {
		    $string = $string . "intron $j\t$chr:$intronstart{$chr}[$gc][$i]-$intronend{$chr}[$gc][$i]\t$intron_count{$chr}[$gc][$i]\t$ave\t$ave_norm\t$intron_length\n";
		}
		else {
		    $k = $numexons{$chr}[$gc] - $j;
		    $string = "intron $k\t$chr:$intronstart{$chr}[$gc][$i]-$intronend{$chr}[$gc][$i]\t$intron_count{$chr}[$gc][$i]\t$ave\t$ave_norm\t$intron_length\n". $string;
		}
	    }
	}
	if($gene_length > 0) {
	    $ave = $gene_count / $gene_length;
	}
	else {
	    $ave = 0;
	}
	$ave = int(10000 * $ave) / 10000;
	$ave_norm = $ave / $coverage_normalization_factor;
	$ave_norm = int(10000 * $ave_norm) / 10000;
	print "\t$gene_count\t$ave\t$ave_norm\t$gene_length\n";
	print $string;
    }
}
