#!/usr/bin/perl

# Written by Gregory R. Grant
# University of Pennslyvania, 2010
$|=1;

if(@ARGV < 3) {
    die "
Usage: compare_feature_quantifications_between_two_samples.pl <quant_file1> <quant_file2> <min_depth> [options]

Where:  <quant_file1> and <quant_file2> are feature quantification files

        <min_depth> is the minimum average depth-of-coverage that each gene must have
        in at least one of the two conditions in order for the gene to be considered.

This program returns (by default) genes ranked by fold change.  Use the options to 
output at the exon or intron level.

Options: -exons   : rank exons by fold change
         -introns : rank introns by fold change
         -raf x   : ratio adjustment factor (added to numerator and denominator to avoid
                    small numbers in the denominator blowing up the ratio).  Default is
                    (ave_cond1 + ave_cond2) / 20.
         -annot f : f is a file of gene annotation with col 1 being the id and col 2
                    being the annotation that is used in the output.  File is tab delimited.

Note: -exons and -introns can both be set, but if either is set it will not report gene-level
results, to get genes and exons/introns you have to run twice.

";
}
$min_depth = $ARGV[2];
$exons="false";
$introns="false";
$userraf = "false";
$annot_exists = "false";
for($i=3; $i<@ARGV; $i++) {
    $optionrecognized = 0;
    if($ARGV[$i] eq "-exons") {
	$exons = "true";
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-introns") {
	$introns = "true";
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-raf") {
	$userraf = "true";
	$raf = $ARGV[$i+1];
	$i++;
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-annot") {
	$annotfile = $ARGV[$i+1];
	$i++;
	$annot_exists = "true";
	$optionrecognized = 1;
    }
    if($optionrecognized == 0) {
	print STDERR "\nError: option \'$ARGV[$i]\' is not recognized\n\n";
	exit(0);
    }
}

if($annot_exists eq "true") {
    open(INFILE, $annotfile) or die "Error: Cannot open file '$annotfile' for reading.\n\n";
    while($line = <INFILE>) {
	chomp($line);
	@a = split(/\t/,$line);
	$ANNOT{$a[0]} = $a[1];
    }
    close(INFILE);
}

open(INFILE, $ARGV[0]);
$line = <INFILE>;
$line = <INFILE>;
$line = <INFILE>; # this is the ----------- ... line
$genecounter = 0;
$gene_ave = 0;
$exon_ave = 0;
$intron_ave = 0;
while($line = <INFILE>) { # this is the gene id line
    chomp($line);
    $geneid[$genecounter] = $line;
    $line = <INFILE>; # this is the header line that each gene has
    $line = <INFILE>; # this is the line for the full gene (sum of all exons)
    chomp($line);
    $line =~ s/ //g;
    @a = split(/\t/,$line);
    $gene_loc[$genecounter] = $a[1];
    $gene_ave_count[$genecounter] = $a[3];
    $gene_ave_norm[$genecounter] = $a[4];
    $gene_ave = $gene_ave + $a[4];
    $line = <INFILE>; # this is the first exon line
    chomp($line);
    until(($line =~ /----------/) || !($line =~ /\S/)) {
	$line =~ s/ //g;
	@a = split(/\t/,$line);
	if($a[0] =~ /exon/) {
	    $exon_ave_count{$a[1]} = $a[3];
	    $exon_ave_norm{$a[1]} = $a[4];
	}
	if($a[0] =~ /intron/) {
	    $intron_ave_count{$a[1]} = $a[3];
	    $intron_ave_norm{$a[1]} = $a[4];
	}
	$line = <INFILE>;
	chomp($line);
    }
    $genecounter++;
}
close(INFILE);
$gene_ave = $gene_ave / $genecounter;

open(INFILE, $ARGV[1]);
$line = <INFILE>;
$line = <INFILE>;
$line = <INFILE>; # this is the ----------- ... line
$genecounter = 0;
$gene_ave2 = 0;
while($line = <INFILE>) { # this is the gene id line
    chomp($line);
    $geneid2[$genecounter] = $line;
    $line = <INFILE>; # this is the header line that each gene has
    $line = <INFILE>; # this is the line for the full gene (sum of all exons)
    chomp($line);
    $line =~ s/ //g;
    @a = split(/\t/,$line);
    $gene_loc2[$genecounter] = $a[1];
    $gene_ave_count2[$genecounter] = $a[3];
    $gene_ave_norm2[$genecounter] = $a[4];
    $gene_ave2 = $gene_ave2 + $a[4];
    $line = <INFILE>; # this is the first exon line
    chomp($line);
    until(($line =~ /----------/) || !($line =~ /\S/)) {
	$line =~ s/ //g;
	@a = split(/\t/,$line);
	if($a[0] =~ /exon/) {
	    $exon_ave_count2{$a[1]} = $a[3];
	    $exon_ave_norm2{$a[1]} = $a[4];
	}
	if($a[0] =~ /intron/) {
	    $intron_ave_count2{$a[1]} = $a[3];
	    $intron_ave_norm2{$a[1]} = $a[4];
	}
	$line = <INFILE>;
	chomp($line);
    }
    $genecounter++;
}
close(INFILE);
$gene_ave2 = $gene_ave2 / $genecounter;

$ratio_adjustment_factor = ($gene_ave + $gene_ave2) / 20;
if($userraf eq "true") {
    $ratio_adjustment_factor = $raf;
}
if($ratio_adjustment_factor == 0) {
    $ratio_adjustment_factor = .0000001;
}

if($exons eq "false" && $introns eq "false") {
    print "GENE_ID\tLocation\tintensity1\tintensity2\tadj-ratio\n";
    for($i=0; $i<$genecounter; $i++) {
	$gene_ratio[$i] = ($gene_ave_norm[$i]+$ratio_adjustment_factor) / ($gene_ave_norm2[$i]+$ratio_adjustment_factor);
	if($gene_ratio[$i] < 1) {
	    $gene_ratio[$i] = 1/$gene_ratio[$i];
	}
	if($gene_ave_count[$i] >= $min_depth || $gene_ave_count2[$i] >= $min_depth) {
	    $geneid[$i] =~ s/\s+(\+|-)\s*$//;
	    $ID = $geneid[$i];
	    $ID =~ s/\(.*//;
	    $u = $ANNOT{$ID};
	    $name = "";
	    if($u =~ /\S/) {
		$name = $u;
	    } else {
		$ID = $geneid[$i];
		$ID =~ s/.*:::://;
		$ID =~ s/\(.*//;
		$u = $ANNOT{$ID};
		if($u =~ /\S/) {
		    $name = $u;
		}
	    }
	    $gene_hash{"$geneid[$i]\t$gene_loc[$i]\t$gene_ave_norm[$i]\t$gene_ave_norm2[$i]"} = $gene_ratio[$i];
	    if($name =~ /\S/) {
		$names{"$geneid[$i]\t$gene_loc[$i]\t$gene_ave_norm[$i]\t$gene_ave_norm2[$i]"} = $name;
	    }
	}
    }
    foreach $key (sort {$gene_hash{$b}<=>$gene_hash{$a}} keys %gene_hash) {
	$gene_ratio = $gene_hash{$key};
	$name = $names{$key};
	$key =~ s/::::/, /g;
	$key =~ s/_genes//g;
	print "$key\t$gene_ratio\t$name\n";
    }
}
if($exons eq "true") {
    foreach $exon (keys %exon_ave_norm) {
	$exon_ratio{$exon} = ($exon_ave_norm{$exon}+$ratio_adjustment_factor) / ($exon_ave_norm2{$exon}+$ratio_adjustment_factor);
	if($exon_ratio{$exon} < 1) {
	    $exon_ratio{$exon} = 1/$exon_ratio{$exon};
	}
	if($exon_ave_count{$exon} >= $min_depth || $exon_ave_count2{$exon} >= $min_depth) {
	    $feature_hash{"$exon\tEXON\t$exon_ave_norm{$exon}\t$exon_ave_norm2{$exon}"} = $exon_ratio{$exon};
	}	
    }
}

if($introns eq "true") {
    foreach $intron (keys %intron_ave_norm) {
	$intron_ratio{$intron} = ($intron_ave_norm{$intron}+$ratio_adjustment_factor) / ($intron_ave_norm2{$intron}+$ratio_adjustment_factor);
	if($intron_ratio{$intron} < 1) {
	    $intron_ratio{$intron} = 1/$intron_ratio{$intron};
	}
	if($intron_ave_count{$intron} >= $min_depth || $intron_ave_count2{$intron} >= $min_depth) {
	    $feature_hash{"$intron\tINTRON\t$intron_ave_norm{$intron}\t$intron_ave_norm2{$intron}"} = $intron_ratio{$intron};
	}	
    }
}
if($exons eq "true" || $introns eq "true") {
    print "Location\ttype\tintensity1\tintensity2\tadj-ratio\n";
    foreach $key (sort {$feature_hash{$b}<=>$feature_hash{$a}} keys %feature_hash) {
	$feature_ratio = $feature_hash{$key};
	print "$key\t$feature_ratio\n";
    }
}
