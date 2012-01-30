#/usr/bin/perl

# Written by Gregory R. Grant
# University of Pennsylvania, 2010

if(@ARGV<1 || $ARGV[0] eq "/help/") {
    print "\nUsage: featurequant2geneprofiles.pl <feature_quantification_files> [options]\n\n";
    print "Profiles are output for all genes/exons/introns, by default.  To change this use the options below.\n\n";
    print "<feature_quantification_files> is a space separated list of feature quantification files.\n\n";
    print "options:\n";
    print "     -genes    : output values for genes only\n";
    print "     -exons    : output values for exons only\n";
    print "     -introns  : output values for introns only\n";
    print "     -features : output values for exons and introns only\n";
    print "     -names=\"name1,,,name2,,, ... ,,,nameN\" : create a header line with these names.\n";
    print "     -simple   : if in -exon or -intron mode, then print out as two column table without qualifiers.\n";
    print "     -printheader : print a header line.\n";
    print "     -sort n   : sort column n.  For n>0, n sorts decreasing, -n sorts increasing.\n";
    print "     -locations   : output also the location of the feature.\n";
    print "     -cnt      : report the avereage depth, unnormalized for number of bases mapped.\n";
    print "     -annot x  : x is the name of a file of annotation, first column is the id in the feature\n";
    print "                 quantification file and the second column is the annotation.\n";
    print "\n";
    exit();
}

for($i=0; $i<@ARGV; $i++) {
    if(-e $ARGV[$i]) {
	$numfiles = $i + 1;
    } else {
	$i = @ARGV;
    }
}

if($numfiles < 1) {
    print "ERROR: no valid files given.\n";
    exit();
}

$genesonly = "false";
$exonsonly = "false";
$intronsonly = "false";
$featuresonly = "false";
$all = "true";
$printheader = "false";
$simple = "false";
$sort = "false";
$sort_decreasing = "false";
$locations = "false";
$reportcnt = "false";
$annotfile_given = "false";
$annotfile = "";
for($i=$numfiles; $i<@ARGV; $i++) {
    $optionrecognized = 0;
    if($ARGV[$i] eq "-annot") {
	$annotfile_given = "true";
        $i++;
        $annotfile = $ARGV[$i];
        if(!(-e $annotfile)) {
            die "Error: annotation file '$annotfile' does not seem to exist.\n\n";
        }
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-cnt") {
	$reportcnt = "true";
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-genes") {
	$genesonly = "true";
	$all = "false";
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-sort") {
	$sort = "true";
	$i++;
	if($ARGV[$i] =~ /[^-\d]/) {
	    die "\nError: the parameter to -sort must be a non-zero integer\n\n.";
	} else {
	    $sortcol = $ARGV[$i];
	    if($sortcol == 0) {
		die "\nError: the parameter to -sort must be a non-zero integer\n\n.";
	    }
	    if($sortcol > 0) {
		$sort_decreasing = "true";
	    } else {
		$sort_decreasing = "false";
		$sortcol = $sortcol * -1;
	    }
	    $sortcol--;
	}
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-exons") {
	$exonsonly = "true";
	$all = "false";
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-introns") {
	$intronsonly = "true";
	$all = "false";
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-features") {
	$featuresonly = "true";
	$all = "false";
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-locations") {
	$locations = "true";
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-simple") {
	$simple = "true";
	$optionrecognized = 1;
    }
    if($ARGV[$i] =~ /names?=(.*)/) {
	@names = split(/,,,/,$1);
	if(@names != $numfiles) {
	    print "Error: number of names must equal the number of files.\n";
	    exit();
	}
	$printheader = "true";
	$optionrecognized = 1;
    }    
    if($ARGV[$i] eq "-printheader") {
	$printheader = "true";
	$optionrecognized = 1;
    }
    if($optionrecognized == 0) {
	print "\nERROR: option $ARGV[$i] not recognized\n";
	exit();
    }
}

open(INFILE, $annotfile);
while($line = <INFILE>) {
    chomp($line);
    @a = split(/\t/,$line);
    $ANNOT{$a[0]} = $a[1];
}
close(INFILE);

for($i=0; $i<$numfiles; $i++) {
    $CNT = 0;
    if(!(-e $ARGV[$i])) {
	print "\nERROR: file $ARGV[$i] not found.\n\n";
	exit();
    }
    open(INFILE, $ARGV[$i]);
    while($line = <INFILE>) {
	chomp($line);
	if($line =~ /---------------------------/) {
	    $line = <INFILE>;
	    chomp($line);
	    $line =~ s/\t(\+|-)//;
	    $geneid = $line;
	    $ALL[$CNT][$i][0] = $geneid;
	    $line = <INFILE>;
	    next;
	}
	if($line =~ /gene/) {
	    @a = split(/\t/,$line);
	    if($genesonly eq "true") {
		if($reportcnt eq "false") {
		    $profile{$geneid}[$i] = $a[4];
		} else {
		    $profile{$geneid}[$i] = $a[3];
		}
		$genelocation{$geneid} = $a[1];
	    } 
	    if($all eq "true") {
		$a[0] =~ s/^\s+//;
		$a[0] =~ s/\s+$//;
		$ALL[$CNT][$i][1] = $a[1];
		if($reportcnt eq "false") {
		    $ALL[$CNT][$i][2] = $a[4];
		} else {
		    $ALL[$CNT][$i][2] = $a[3];
		}
		$CNT++;
	    }
	}
	if($line =~ /exon/) {
	    @a = split(/\t/,$line);
	    if($exonsonly eq "true" || $featuresonly eq "true") {
		if($reportcnt eq "false") {
		    $exon{$a[1]}[$i] = $a[4];
		} else {
		    $exon{$a[1]}[$i] = $a[3];
		}
		$exonlocation{$geneid} = $a[1];
	    } 
	    if($all eq "true") {
		$a[0] =~ s/^\s+//;
		$a[0] =~ s/\s+$//;
		$ALL[$CNT][$i][0] = $a[0];
		$ALL[$CNT][$i][1] = $a[1];
		if($reportcnt eq "false") {
		    $ALL[$CNT][$i][2] = $a[4];
		} else {
		    $ALL[$CNT][$i][2] = $a[3];
		}
		$CNT++;
	    }
	}
	if($line =~ /intron/) {
	    @a = split(/\t/,$line);
	    if($intronsonly eq "true" || $featuresonly eq "true") {
		if($reportcnt eq "false") {
		    $intron{$a[1]}[$i] = $a[4];
		} else {
		    $intron{$a[1]}[$i] = $a[3];
		}
		$intronlocation{$geneid} = $a[1];
	    }
	    if($all eq "true") {
		$a[0] =~ s/^\s+//;
		$a[0] =~ s/\s+$//;
		$ALL[$CNT][$i][0] = $a[0];
		$ALL[$CNT][$i][1] = $a[1];
		if($reportcnt eq "false") {
		    $ALL[$CNT][$i][2] = $a[4];
		} else {
		    $ALL[$CNT][$i][2] = $a[3];
		}
		$CNT++;
	    }
	}
    }
}

if($printheader eq "true") {
    if($simple eq "false") {
	print "\t";
    }
    print "name";
    if($locations eq "true") {
	print "\tlocation";
    }
    for($i=0; $i<$numfiles; $i++) {
	if($names[$i] =~ /\S/) {
	    print "\t$names[$i]";
	} else {
	    $j = $i+1;
	    print "\tfile_$j";
	}
    }
    print "\n";
}

if($all eq "true") {
    for($cnt=0; $cnt<$CNT; $cnt++) {
	$IDout = $ALL[$cnt][0][0];
	$IDout =~ s/::::/, /g;
	$IDout =~ s/_genes//g;
	print "$IDout";
	$ID = $ALL[$cnt][0][0];
	$ID =~ s/\(.*//;
	if(!($ANNOT{$ID} =~ /\S/)) {
	    $ID = $ALL[$cnt][0][0];
	    $ID =~ s/.*://;
	    $ID =~ s/\(.*//;
	}	
	print "\t$ALL[$cnt][0][1]";
	for($i=0; $i<$numfiles;$i++) {
	    print "\t$ALL[$cnt][$i][2]";
	}
	if($ANNOT{$ID} =~ /\S/) {
	    print "\t$ANNOT{$ID}";
	}
	print "\n";
    }
}

if($genesonly eq "true") {
    if($sort eq "true" && $sort_decreasing eq "true") {
	foreach $geneid (sort {$profile{$b}[$sortcol]<=>$profile{$a}[$sortcol]} keys %genelocation) {
	    $IDout = $geneid;
	    $IDout =~ s/::::/, /g;
	    $IDout =~ s/_genes//g;
	    print "$IDout";
	    $ID = $geneid;
	    $ID =~ s/\(.*//;
	    if(!($ANNOT{$ID} =~ /\S/)) {
		$ID = $geneid;
		$ID =~ s/.*://;
		$ID =~ s/\(.*//;
	    }
	    if($locations eq "true") {
		print "\t$genelocation{$geneid}";
	    }
	    for($i=0; $i<$numfiles; $i++) {
		print "\t$profile{$geneid}[$i]";
	    }
	    if($ANNOT{$ID} =~ /\S/) {
		print "\t$ANNOT{$ID}";
	    }
	    print "\n";
	}
    }
    if($sort eq "true" && $sort_decreasing eq "false") {
	foreach $geneid (sort {$profile{$a}[$sortcol]<=>$profile{$b}[$sortcol]} keys %genelocation) {
	    $IDout = $geneid;
	    $IDout =~ s/::::/, /g;
	    $IDout =~ s/_genes//g;
	    print "$IDout";
	    $ID = $geneid;
	    $ID =~ s/\(.*//;
	    if(!($ANNOT{$ID} =~ /\S/)) {
		$ID = $geneid;
		$ID =~ s/.*://;
		$ID =~ s/\(.*//;
	    }
	    if($locations eq "true") {
		print "\t$genelocation{$geneid}";
	    }
	    for($i=0; $i<$numfiles; $i++) {
		print "\t$profile{$geneid}[$i]";
	    }
	    if($ANNOT{$ID} =~ /\S/) {
		print "\t$ANNOT{$ID}";
	    }
	    print "\n";
	}
    }
    if($sort eq "false") {
	foreach $geneid (sort {$genelocation{$a} cmp $genelocation{$b}} keys %genelocation) {
	    $IDout = $geneid;
	    $IDout =~ s/::::/, /g;
	    $IDout =~ s/_genes//g;
	    print "$IDout";
	    $ID = $geneid;
	    $ID =~ s/\(.*//;
	    if(!($ANNOT{$ID} =~ /\S/)) {
		$ID = $geneid;
		$ID =~ s/.*://;
		$ID =~ s/\(.*//;
	    }
	    if($locations eq "true") {
		print "\t$genelocation{$geneid}";
	    }
	    for($i=0; $i<$numfiles; $i++) {
		print "\t$profile{$geneid}[$i]";
	    }
	    if($ANNOT{$ID} =~ /\S/) {
		print "\t$ANNOT{$ID}";
	    }
	    print "\n";
	}
    }
}

if($exonsonly eq "true" || $featuresonly eq "true") {
    if($sort eq "true" && $sort_decreasing eq "true") {
	foreach $exonid (sort {$exon{$b}[$sortcol]<=>$exon{$a}[$sortcol]} keys %exon) {
	    if($simple eq "false") {
		print "$exonid\tEXON";
	    } else {
		print "$exonid";
	    }
	    for($i=0; $i<$numfiles; $i++) {
		print "\t$exon{$exonid}[$i]";
	    }
	    print "\n";
	}
    }
    if($sort eq "true" && $sort_decreasing eq "false") {
	foreach $exonid (sort {$exon{$a}[$sortcol]<=>$exon{$b}[$sortcol]} keys %exon) {
	    if($simple eq "false") {
		print "$exonid\tEXON";
	    } else {
		print "$exonid";
	    }
	    for($i=0; $i<$numfiles; $i++) {
		print "\t$exon{$exonid}[$i]";
	    }
	    print "\n";
	}
    }
    if($sort eq "false") {
	foreach $exonid (sort {$exonlocation{$a} cmp $exonlocation{$b}} keys %exon) {
	    if($simple eq "false") {
		print "$exonid\tEXON";
	    } else {
		print "$exonid";
	    }
	    for($i=0; $i<$numfiles; $i++) {
		print "\t$exon{$exonid}[$i]";
	    }
	    print "\n";
	}
    }
}

if($intronsonly eq "true" || $featuresonly eq "true") {
    if($sort eq "true" && $sort_decreasing eq "true") {
	foreach $intronid (sort {$intron{$b}[$sortcol]<=>$intron{$a}[$sortcol]} keys %intron) {
	    if($simple eq "false") {
		print "$intronid\tINTRON";
	    } else {
		print "$intronid";
	    }
	    for($i=0; $i<$numfiles; $i++) {
		print "\t$intron{$intronid}[$i]";
	    }
	    print "\n";
	}
    }
    if($sort eq "true" && $sort_decreasing eq "false") {
	foreach $intronid (sort {$intron{$a}[$sortcol]<=>$intron{$b}[$sortcol]} keys %intron) {
	    if($simple eq "false") {
		print "$intronid\tINTRON";
	    } else {
		print "$intronid";
	    }
	    for($i=0; $i<$numfiles; $i++) {
		print "\t$intron{$intronid}[$i]";
	    }
	    print "\n";
	}
    }
    if($sort eq "false") {
	foreach $intronid (sort {$intronlocation{$a} cmp $intronlocation{$b}} keys %intron) {
	    if($simple eq "false") {
		print "$intronid\tINTRON";
	    } else {
		print "$intronid";
	    }
	    for($i=0; $i<$numfiles; $i++) {
		print "\t$intron{$intronid}[$i]";
	    }
	    print "\n";
	}
    }
}

# --------------------------------------------------------------------
# PFD0028w        +
#     Type        Location                Count   Ave_Cnt Ave_Nrm Length
#     gene        Pf3D7_04:67853-67936    0       0       0       84
#   exon 1        Pf3D7_04:67853-67936    0       0       0       84
# --------------------------------------------------------------------
