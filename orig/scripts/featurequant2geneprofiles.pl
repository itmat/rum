#!/usr/bin/perl

# Written by Gregory R. Grant
# University of Pennsylvania, 2010

$|=1;

if(@ARGV<1 || $ARGV[0] eq "/help/") {
    print "\nUsage: featurequant2geneprofiles.pl <outfile> <feature_quantification_files> [options]\n\n";
    print "Profiles are output for all genes/exons/introns, by default.  To change this use the options below.\n\n";
    print "<feature_quantification_files> is a space separated list of feature quantification files,\nwhich are output from the script rum2quantifications.pl.\n\n";
    print "options:\n";
    print "     -genes    : output values for genes only\n";
    print "\n";
    print "     -exons    : output values for exons only\n";
    print "\n";
    print "     -introns  : output values for introns only\n";
    print "\n";
    print "     -features : output values for exons and introns only\n";
    print "\n";
    print "     -names=\"name1,,,name2,,, ... ,,,nameN\" : create a header line with these names.\n";
    print "\n";
    print "     -simple   : if in -exon or -intron mode, print without 'EXON' and 'INTRON' qualifiers.\n";
    print "\n";
    print "     -printheader : print a header line.\n";
    print "\n";
    print "     -sort1 n   : If using -genes, -exons or -introns, this will sort on column n.\n                  For n>0, n sorts decreasing, -n sorts increasing.\n                  Sorts both min and max files by the min file.\n                  Also use this to sort when using the -sformat option.\n";
    print "\n";
    print "     -sort2 n   : If using -genes, -exons or -introns, this will sort on column n.\n                  For n>0, n sorts decreasing, -n sorts increasing.\n                  Sorts both min and max files by the max file.\n";
    print "\n";
    print "     -sort3 n   : If using -genes, -exons or -introns, this will sort on column n.\n                  For n>0, n sorts decreasing, -n sorts increasing.\n                  Sorts both min and max files separately.\n";
    print "\n";
    print "     -locations : output also the location of the feature.\n";
    print "\n";
    print "     -cnt       : report the avereage depth, unnormalized for number of bases mapped.\n";
    print "                  This only works if using the -sformat option.\n";
    print "\n";
    print "     -d         : write the differences max-min to <outfile>.diff.\n";
    print "\n";
    print "     -annot x   : x is the name of a file of annotation, first column is the id in the feature\n";
    print "                  quantification file and the second column is the annotation.\n";
    print "\n";
    print "     -sformat   : input files are in format output from rum2quantifications.pl when the\n                  -sepout option is used to that script.\n";
    print "\n";
    exit();
}

$outfile = $ARGV[0];

for($i=1; $i<@ARGV; $i++) {
    if(-e $ARGV[$i]) {
	$numfiles = $i;
    } else {
	$i = @ARGV-1;
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
$sort1 = "false";
$sort2 = "false";
$sort3 = "false";
$sort_decreasing = "false";
$locations = "false";
$reportcnt = "false";
$annotfile_given = "false";
$annotfile = "";
$sformat = "false";
$writediff = "false";
for($i=$numfiles+1; $i<@ARGV; $i++) {
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
    if($ARGV[$i] eq "-sformat") {
	$sformat = "true";
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-genes") {
	$genesonly = "true";
	$all = "false";
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-d") {
	$writediff = "true";
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-sort1") {
	$sort1 = "true";
	$i++;
	if($ARGV[$i] =~ /[^-\d]/) {
	    die "\nError: the parameter to -sort1 must be a non-zero integer\n\n.";
	} else {
	    $sortcol1 = $ARGV[$i];
	    if($sortcol1 == 0) {
		die "\nError: the parameter to -sort1 must be a non-zero integer\n\n.";
	    }
	    if($sortcol1 > 0) {
		$sort_decreasing = "true";
	    } else {
		$sort_decreasing = "false";
		$sortcol1 = $sortcol1 * -1;
	    }
	    $sortcol1--;
	}
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-sort2") {
	$sort2 = "true";
	$i++;
	if($ARGV[$i] =~ /[^-\d]/) {
	    die "\nError: the parameter to -sort2 must be a non-zero integer\n\n.";
	} else {
	    $sortcol2 = $ARGV[$i];
	    if($sortcol2 == 0) {
		die "\nError: the parameter to -sort2 must be a non-zero integer\n\n.";
	    }
	    if($sortcol2 > 0) {
		$sort_decreasing = "true";
	    } else {
		$sort_decreasing = "false";
		$sortcol2 = $sortcol2 * -1;
	    }
	    $sortcol2--;
	}
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-sort3") {
	$sort3 = "true";
	$i++;
	if($ARGV[$i] =~ /[^-\d]/) {
	    die "\nError: the parameter to -sort3 must be a non-zero integer\n\n.";
	} else {
	    $sortcol3 = $ARGV[$i];
	    if($sortcol3 == 0) {
		die "\nError: the parameter to -sort3 must be a non-zero integer\n\n.";
	    }
	    if($sortcol3 > 0) {
		$sort_decreasing = "true";
	    } else {
		$sort_decreasing = "false";
		$sortcol3 = $sortcol3 * -1;
	    }
	    $sortcol3--;
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

if($writediff eq "true" && $sformat eq "true") {
    die "\nError: sorry, you can't specify both -d and -sformat.\n\n";
}

$num_sort=0;
if($sort1 eq "true") {
    $num_sort++;
}
if($sort2 eq "true") {
    $num_sort++;
}
if($sort3 eq "true") {
    $num_sort++;
}
if($num_sort > 1) {
    die "\nError: only specify one of -sort1, -sort2, -sort3\n\n";
}

if($sformat eq "true") {
    $sort = $sort1;
}

if($sformat eq "true") {
    open(OUTFILE1, ">$outfile");
} else {
    $f = $outfile . ".min";
    open(OUTFILE1, ">$f");
    $f = $outfile . ".max";
    open(OUTFILE2, ">$f");
    if($writediff eq "true") {
	$f = $outfile . ".diff";
	open(OUTFILE3, ">$f");
    }
}

if($annotfile_given eq "true") {
    open(INFILE, $annotfile);
    while($line = <INFILE>) {
	chomp($line);
	@a = split(/\t/,$line);
	$ANNOT{$a[0]} = $a[1];
    }
    close(INFILE);
}

for($i=1; $i<$numfiles+1; $i++) {
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
	    if($sformat eq "true") {
		$ALL[$CNT][$i-1][0] = $geneid;
	    } else {
   		$ALL_min[$CNT][$i-1][0] = $geneid;
		$ALL_max[$CNT][$i-1][0] = $geneid;
	    }
	    $line = <INFILE>;
	    next;
	}
	if($line =~ /transcript/) {
	    @a = split(/\t/,$line);
	    if($genesonly eq "true") {
		if($sformat eq "true") {
		    if($reportcnt eq "false") {
			$profile{$geneid}[$i-1] = $a[4];
    		    } else {
			$profile{$geneid}[$i-1] = $a[3];
		    }
		} else {
		    $profile_min{$geneid}[$i-1] = $a[2];
		    $profile_max{$geneid}[$i-1] = $a[3];
		}
		$genelocation{$geneid} = $a[1];
	    } 
	    if($all eq "true") {
		$a[0] =~ s/^\s+//;
		$a[0] =~ s/\s+$//;
		if($sformat eq "true") {
		    $ALL[$CNT][$i-1][1] = $a[1];
		    if($reportcnt eq "false") {
			$ALL[$CNT][$i-1][2] = $a[4];
		    } else {
			$ALL[$CNT][$i-1][2] = $a[3];
		    }
		} else {
		    $ALL_min[$CNT][$i-1][1] = $a[1];
		    $ALL_max[$CNT][$i-1][1] = $a[1];
		    $ALL_min[$CNT][$i-1][2] = $a[2];
		    $ALL_max[$CNT][$i-1][2] = $a[3];
		}
		$CNT++;
	    }
	}
	if($line =~ /exon/) {
	    @a = split(/\t/,$line);
	    if($exonsonly eq "true" || $featuresonly eq "true") {
		if($sformat eq "true") {
		    if($reportcnt eq "false") {
			$exon{$a[1]}[$i-1] = $a[4];
		    } else {
			$exon{$a[1]}[$i-1] = $a[3];
		    }
		} else {
			$exon_min{$a[1]}[$i-1] = $a[2];
			$exon_max{$a[1]}[$i-1] = $a[3];
		}
		$exonlocation{$geneid} = $a[1];
	    } 
	    if($all eq "true") {
		$a[0] =~ s/^\s+//;
		$a[0] =~ s/\s+$//;
		if($sformat eq "true") {
		    $ALL[$CNT][$i-1][0] = $a[0];
		    $ALL[$CNT][$i-1][1] = $a[1];
		    if($reportcnt eq "false") {
			$ALL[$CNT][$i-1][2] = $a[4];
		    } else {
			$ALL[$CNT][$i-1][2] = $a[3];
		    }
		} else {
		    $ALL_min[$CNT][$i-1][0] = $a[0];
		    $ALL_min[$CNT][$i-1][1] = $a[1];
		    $ALL_max[$CNT][$i-1][0] = $a[0];
		    $ALL_max[$CNT][$i-1][1] = $a[1];
		    $ALL_min[$CNT][$i-1][2] = $a[2];
		    $ALL_max[$CNT][$i-1][2] = $a[3];
		}
		$CNT++;
	    }
	}
	if($line =~ /intron/) {
	    @a = split(/\t/,$line);
	    if($intronsonly eq "true" || $featuresonly eq "true") {
		if($sformat eq "true") {
		    if($reportcnt eq "false") {
			$intron{$a[1]}[$i-1] = $a[4];
		    } else {
			$intron{$a[1]}[$i-1] = $a[3];
		    }
		} else {
			$intron_min{$a[1]}[$i-1] = $a[2];
			$intron_max{$a[1]}[$i-1] = $a[3];
		}
		$intronlocation{$geneid} = $a[1];
	    }
	    if($all eq "true") {
		$a[0] =~ s/^\s+//;
		$a[0] =~ s/\s+$//;
		if($sformat eq "true") {
		    $ALL[$CNT][$i-1][0] = $a[0];
		    $ALL[$CNT][$i-1][1] = $a[1];
		    if($reportcnt eq "false") {
			$ALL[$CNT][$i-1][2] = $a[4];
		    } else {
			$ALL[$CNT][$i-1][2] = $a[3];
		    }
		} else {
		    $ALL_min[$CNT][$i-1][0] = $a[0];
		    $ALL_min[$CNT][$i-1][1] = $a[1];
		    $ALL_max[$CNT][$i-1][0] = $a[0];
		    $ALL_max[$CNT][$i-1][1] = $a[1];
		    $ALL_min[$CNT][$i-1][2] = $a[2];
		    $ALL_max[$CNT][$i-1][2] = $a[3];
		}
		$CNT++;
	    }
	}
    }
}

if($printheader eq "true") {
    if($simple eq "false") {
	print OUTFILE1 "\t";
	if($sformat eq "false") {
	    print OUTFILE2 "\t";
	}
	if($writediff eq "true") {
	    print OUTFILE3 "\t";
	}
    }

    print OUTFILE1 "name";
    if($sformat eq "false") {
	    print OUTFILE2 "name";
    }
    if($writediff eq "true") {
	print OUTFILE3 "name";
    }
    if($locations eq "true") {
	print OUTFILE1 "\tlocation";
	if($sformat eq "false") {
	    print OUTFILE2 "\tlocation";
	}
	if($writediff eq "true") {
	    print OUTFILE3 "\tlocation";
	}
    }
    for($i=0; $i<$numfiles; $i++) {
	if($names[$i] =~ /\S/) {
	    print OUTFILE1 "\t$names[$i]";
	    if($sformat eq "false") {
		print OUTFILE2 "\t$names[$i]";
	    }
	    if($writediff eq "true") {
		print OUTFILE3 "\t$names[$i]";
	    }
	} else {
	    $j = $i+1;
	    print OUTFILE1 "\tfile_$j";
	    if($sformat eq "false") {
		print OUTFILE2 "\tfile_$j";
	    }
	    if($writediff eq "true") {
		print OUTFILE3 "\tfile_$j";
	    }
	}
    }
    print OUTFILE1 "\n";
    if($sformat eq "false") {
	print OUTFILE2 "\n";
    }
    if($writediff eq "true") {
	print OUTFILE3 "\n";
    }
}

if($all eq "true") {
    if($sformat eq "true") {
	print STDERR "here\n";
	for($cnt=0; $cnt<$CNT; $cnt++) {
	    $IDout = $ALL[$cnt][0][0];
	    $IDout =~ s/::::/, /g;
	    $IDout =~ s/_genes//g;
	    print OUTFILE1 "$IDout";
	    $ID = $ALL[$cnt][0][0];
	    if(!($ANNOT{$ID} =~ /\S/)) {
		$ID =~ s/\(.*//;
	    } elsif(!($ANNOT{$ID} =~ /\S/)) {
		$ID = $ALL[$cnt][0][0];
		$ID =~ s/.*://;
	    } elsif(!($ANNOT{$ID} =~ /\S/)) {
		$ID = $ALL[$cnt][0][0];
		$ID =~ s/.*://;
		$ID =~ s/\(.*//;
	    } else {
		$ID = $ALL[$cnt][0][0];
	    }

	    print OUTFILE1 "\t$ALL[$cnt][0][1]";
	    for($i=0; $i<$numfiles;$i++) {
		print OUTFILE1 "\t$ALL[$cnt][$i][2]";
	    }
	    if($ANNOT{$ID} =~ /\S/) {
		print OUTFILE1 "\t$ANNOT{$ID}";
	    }
	    print OUTFILE1 "\n";
	}
    } else {
	for($cnt=0; $cnt<$CNT; $cnt++) {
	    $IDout = $ALL_min[$cnt][0][0];
	    $IDout =~ s/::::/, /g;
	    $IDout =~ s/_genes//g;
	    print OUTFILE1 "$IDout";
	    $ID = $ALL_min[$cnt][0][0];

	    if(!($ANNOT{$ID} =~ /\S/)) {
		$ID =~ s/\(.*//;
	    } elsif(!($ANNOT{$ID} =~ /\S/)) {
		$ID = $ALL_min[$cnt][0][0];
		$ID =~ s/.*://;
	    } elsif(!($ANNOT{$ID} =~ /\S/)) {
		$ID = $ALL_min[$cnt][0][0];
		$ID =~ s/.*://;
		$ID =~ s/\(.*//;
	    } else {
		$ID = $ALL_min[$cnt][0][0];
	    }

	    print OUTFILE1 "\t$ALL_min[$cnt][0][1]";
	    for($i=0; $i<$numfiles;$i++) {
		print OUTFILE1 "\t$ALL_min[$cnt][$i][2]";
	    }
	    if($ANNOT{$ID} =~ /\S/) {
		print OUTFILE1 "\t$ANNOT{$ID}";
	    }
	    print OUTFILE1 "\n";
	}
	for($cnt=0; $cnt<$CNT; $cnt++) {
	    $IDout = $ALL_max[$cnt][0][0];
	    $IDout =~ s/::::/, /g;
	    $IDout =~ s/_genes//g;
	    print OUTFILE2 "$IDout";
	    $ID = $ALL_max[$cnt][0][0];

	    if(!($ANNOT{$ID} =~ /\S/)) {
		$ID =~ s/\(.*//;
	    } elsif(!($ANNOT{$ID} =~ /\S/)) {
		$ID = $ALL_max[$cnt][0][0];
		$ID =~ s/.*://;
	    } elsif(!($ANNOT{$ID} =~ /\S/)) {
		$ID = $ALL_max[$cnt][0][0];
		$ID =~ s/.*://;
		$ID =~ s/\(.*//;
	    } else {
		$ID = $ALL_max[$cnt][0][0];
	    }
	    if(!($ANNOT{$ID} =~ /\S/)) {
		$ID = $ALL_max[$cnt][0][0];
		$ID =~ s/.*://;
		$ID =~ s/\(.*//;
	    }	
	    print OUTFILE2 "\t$ALL_max[$cnt][0][1]";
	    for($i=0; $i<$numfiles;$i++) {
		print OUTFILE2 "\t$ALL_max[$cnt][$i][2]";
	    }
	    if($ANNOT{$ID} =~ /\S/) {
		print OUTFILE2 "\t$ANNOT{$ID}";
	    }
	    print OUTFILE2 "\n";
	}
	for($cnt=0; $cnt<$CNT; $cnt++) {
	    $IDout = $ALL_max[$cnt][0][0];
	    $IDout =~ s/::::/, /g;
	    $IDout =~ s/_genes//g;
	    print OUTFILE3 "$IDout";
	    $ID = $ALL_max[$cnt][0][0];

	    if(!($ANNOT{$ID} =~ /\S/)) {
		$ID =~ s/\(.*//;
	    } elsif(!($ANNOT{$ID} =~ /\S/)) {
		$ID = $ALL_max[$cnt][0][0];
		$ID =~ s/.*://;
	    } elsif(!($ANNOT{$ID} =~ /\S/)) {
		$ID = $ALL_max[$cnt][0][0];
		$ID =~ s/.*://;
		$ID =~ s/\(.*//;
	    } else {
		$ID = $ALL_max[$cnt][0][0];
	    }

	    if(!($ANNOT{$ID} =~ /\S/)) {
		$ID = $ALL_max[$cnt][0][0];
		$ID =~ s/.*://;
		$ID =~ s/\(.*//;
	    }	
	    print OUTFILE3 "\t$ALL_max[$cnt][0][1]";
	    for($i=0; $i<$numfiles;$i++) {
		$X = $ALL_max[$cnt][$i][2] - $ALL_min[$cnt][$i][2];
		print OUTFILE3 "\t$X";
	    }
	    if($ANNOT{$ID} =~ /\S/) {
		print OUTFILE3 "\t$ANNOT{$ID}";
	    }
	    print OUTFILE3 "\n";
	}
    }
}

if($sformat eq "true") {
    if($genesonly eq "true") {
	if($sort eq "true" && $sort_decreasing eq "true") {
	    foreach $geneid (sort {$profile{$b}[$sortcol]<=>$profile{$a}[$sortcol]} keys %genelocation) {
		$IDout = $geneid;
		$IDout =~ s/::::/, /g;
		$IDout =~ s/_genes//g;
		print OUTFILE1 "$IDout";

		$ID = $geneid;
		if(!($ANNOT{$ID} =~ /\S/)) {
		    $ID =~ s/\(.*//;
		} elsif(!($ANNOT{$ID} =~ /\S/)) {
		    $ID = $geneid;
		    $ID =~ s/.*://;
		} elsif(!($ANNOT{$ID} =~ /\S/)) {
		    $ID = $geneid;
		    $ID =~ s/.*://;
		    $ID =~ s/\(.*//;
		} else {
		    $ID = $geneid;
		}

		if($locations eq "true") {
		    print OUTFILE1 "\t$genelocation{$geneid}";
		}
		for($i=0; $i<$numfiles; $i++) {
		    print OUTFILE1 "\t$profile{$geneid}[$i]";
		}
		if($ANNOT{$ID} =~ /\S/) {
		    print OUTFILE1 "\t$ANNOT{$ID}";
		}
		print OUTFILE1 "\n";
	    }
	}
	if($sort eq "true" && $sort_decreasing eq "false") {
	    foreach $geneid (sort {$profile{$a}[$sortcol]<=>$profile{$b}[$sortcol]} keys %genelocation) {
		$IDout = $geneid;
		$IDout =~ s/::::/, /g;
		$IDout =~ s/_genes//g;
		print OUTFILE1 "$IDout";
		$ID = $geneid;
		if(!($ANNOT{$ID} =~ /\S/)) {
		    $ID =~ s/\(.*//;
		} elsif(!($ANNOT{$ID} =~ /\S/)) {
		    $ID = $geneid;
		    $ID =~ s/.*://;
		} elsif(!($ANNOT{$ID} =~ /\S/)) {
		    $ID = $geneid;
		    $ID =~ s/.*://;
		    $ID =~ s/\(.*//;
		} else {
		    $ID = $geneid;
		}

		if($locations eq "true") {
		    print OUTFILE1 "\t$genelocation{$geneid}";
		}
		for($i=0; $i<$numfiles; $i++) {
		    print OUTFILE1 "\t$profile{$geneid}[$i]";
		}
		if($ANNOT{$ID} =~ /\S/) {
		    print OUTFILE1 "\t$ANNOT{$ID}";
		}
		print OUTFILE1 "\n";
	    }
	}
	if($sort eq "false") {
	    foreach $geneid (sort {cmpChrs($genelocation{$a},$genelocation{$b})} keys %genelocation) {
		$IDout = $geneid;
		$IDout =~ s/::::/, /g;
		$IDout =~ s/_genes//g;
		print OUTFILE1 "$IDout";

		$ID = $geneid;
		if(!($ANNOT{$ID} =~ /\S/)) {
		    $ID =~ s/\(.*//;
		} elsif(!($ANNOT{$ID} =~ /\S/)) {
		    $ID = $geneid;
		    $ID =~ s/.*://;
		} elsif(!($ANNOT{$ID} =~ /\S/)) {
		    $ID = $geneid;
		    $ID =~ s/.*://;
		    $ID =~ s/\(.*//;
		} else {
		    $ID = $geneid;
		}

		if($locations eq "true") {
		    print OUTFILE1 "\t$genelocation{$geneid}";
		}
		for($i=0; $i<$numfiles; $i++) {
		    print OUTFILE1 "\t$profile{$geneid}[$i]";
		}
		if($ANNOT{$ID} =~ /\S/) {
		    print OUTFILE1 "\t$ANNOT{$ID}";
		}
		print OUTFILE1 "\n";
	    }
	}
    }
    
    if($exonsonly eq "true" || $featuresonly eq "true") {
	if($sort eq "true" && $sort_decreasing eq "true") {
	    foreach $exonid (sort {$exon{$b}[$sortcol]<=>$exon{$a}[$sortcol]} keys %exon) {
		if($simple eq "false") {
		    print OUTFILE1 "$exonid\tEXON";
		} else {
		    print OUTFILE1 "$exonid";
		}
		for($i=0; $i<$numfiles; $i++) {
		    print OUTFILE1 "\t$exon{$exonid}[$i]";
		}
		print OUTFILE1 "\n";
	    }
	}
	if($sort eq "true" && $sort_decreasing eq "false") {
	    foreach $exonid (sort {$exon{$a}[$sortcol]<=>$exon{$b}[$sortcol]} keys %exon) {
		if($simple eq "false") {
		    print OUTFILE1 "$exonid\tEXON";
		} else {
		    print OUTFILE1 "$exonid";
		}
		for($i=0; $i<$numfiles; $i++) {
		    print OUTFILE1 "\t$exon{$exonid}[$i]";
		}
		print OUTFILE1 "\n";
	    }
	}
	if($sort eq "false") {
	    foreach $exonid (sort {cmpChrs($exonlocation{$a},$exonlocation{$b})} keys %exon) {
		if($simple eq "false") {
		    print OUTFILE1 "$exonid\tEXON";
		} else {
		    print OUTFILE1 "$exonid";
		}
		for($i=0; $i<$numfiles; $i++) {
		    print OUTFILE1 "\t$exon{$exonid}[$i]";
		}
		print OUTFILE1 "\n";
	    }
	}
    }
    
    if($intronsonly eq "true" || $featuresonly eq "true") {
	if($sort eq "true" && $sort_decreasing eq "true") {
	    foreach $intronid (sort {$intron{$b}[$sortcol]<=>$intron{$a}[$sortcol]} keys %intron) {
		if($simple eq "false") {
		    print OUTFILE1 "$intronid\tINTRON";
		} else {
		    print OUTFILE1 "$intronid";
		}
		for($i=0; $i<$numfiles; $i++) {
		    print OUTFILE1 "\t$intron{$intronid}[$i]";
		}
		print OUTFILE1 "\n";
	    }
	}
	if($sort eq "true" && $sort_decreasing eq "false") {
	    foreach $intronid (sort {$intron{$a}[$sortcol]<=>$intron{$b}[$sortcol]} keys %intron) {
		if($simple eq "false") {
		    print OUTFILE1 "$intronid\tINTRON";
		} else {
		    print OUTFILE1 "$intronid";
		}
		for($i=0; $i<$numfiles; $i++) {
		    print OUTFILE1 "\t$intron{$intronid}[$i]";
		}
		print OUTFILE1 "\n";
	    }
	}
	if($sort eq "false") {
	    foreach $intronid (sort {cmpChrs($intronlocation{$a},$intronlocation{$b})} keys %intron) {
		if($simple eq "false") {
		    print OUTFILE1 "$intronid\tINTRON";
		} else {
		    print OUTFILE1 "$intronid";
		}
		for($i=0; $i<$numfiles; $i++) {
		    print OUTFILE1 "\t$intron{$intronid}[$i]";
		}
		print OUTFILE1 "\n";
	    }
	}
    }
}

if($genesonly eq "true") {
    $sort = "false";
    if($sort1 eq "true") {
	foreach $geneid (keys %genelocation) {
	    $sort_hash1{$geneid} = $profile_min{$geneid}[$sortcol];
	    $sort_hash2{$geneid} = $profile_min{$geneid}[$sortcol];
	}
	$sort = "true";
    }
    if($sort2 eq "true") {
	foreach $geneid (keys %genelocation) {
	    $sort_hash1{$geneid} = $profile_max{$geneid}[$sortcol];
	    $sort_hash2{$geneid} = $profile_max{$geneid}[$sortcol];
	}
	$sort = "true";
    }
    if($sort3 eq "true") {
	foreach $geneid (keys %genelocation) {
	    $sort_hash1{$geneid} = $profile_min{$geneid}[$sortcol];
	    $sort_hash2{$geneid} = $profile_max{$geneid}[$sortcol];
	}
	$sort = "true";
    }
    if($sort eq "true") {
	if($sort_decreasing eq "true") {
	    foreach $geneid (sort {$sort_hash1{$b}<=>$sort_hash1{$a}} keys %genelocation) {
		$IDout = $geneid;
		$IDout =~ s/::::/, /g;
		$IDout =~ s/_genes//g;
		print OUTFILE1 "$IDout";
		$ID = $geneid;
		if(!($ANNOT{$ID} =~ /\S/)) {
		    $ID =~ s/\(.*//;
		} elsif(!($ANNOT{$ID} =~ /\S/)) {
		    $ID = $geneid;
		    $ID =~ s/.*://;
		} elsif(!($ANNOT{$ID} =~ /\S/)) {
		    $ID = $geneid;
		    $ID =~ s/.*://;
		    $ID =~ s/\(.*//;
		} else {
		    $ID = $geneid;
		}

		if($locations eq "true") {
		    print OUTFILE1 "\t$genelocation{$geneid}";
		}
		for($i=0; $i<$numfiles; $i++) {
		    print OUTFILE1 "\t$profile_min{$geneid}[$i]";
		}
		if($ANNOT{$ID} =~ /\S/) {
		    print OUTFILE1 "\t$ANNOT{$ID}";
		}
		print OUTFILE1 "\n";
	    }
	    foreach $geneid (sort {$sort_hash2{$b}<=>$sort_hash2{$a}} keys %genelocation) {
		$IDout = $geneid;
		$IDout =~ s/::::/, /g;
		$IDout =~ s/_genes//g;
		print OUTFILE2 "$IDout";
		$ID = $geneid;
		if(!($ANNOT{$ID} =~ /\S/)) {
		    $ID =~ s/\(.*//;
		} elsif(!($ANNOT{$ID} =~ /\S/)) {
		    $ID = $geneid;
		    $ID =~ s/.*://;
		} elsif(!($ANNOT{$ID} =~ /\S/)) {
		    $ID = $geneid;
		    $ID =~ s/.*://;
		    $ID =~ s/\(.*//;
		} else {
		    $ID = $geneid;
		}

		if($locations eq "true") {
		    print OUTFILE2 "\t$genelocation{$geneid}";
		}
		for($i=0; $i<$numfiles; $i++) {
		    print OUTFILE2 "\t$profile_max{$geneid}[$i]";
		}
		if($ANNOT{$ID} =~ /\S/) {
		    print OUTFILE2 "\t$ANNOT{$ID}";
		}
		print OUTFILE2 "\n";
	    }
	    if($writediff eq "true") {
		foreach $geneid (sort {$sort_hash2{$b}<=>$sort_hash2{$a}} keys %genelocation) {
		    $IDout = $geneid;
		    $IDout =~ s/::::/, /g;
		    $IDout =~ s/_genes//g;
		    print OUTFILE3 "$IDout";
		    $ID = $geneid;
		    if(!($ANNOT{$ID} =~ /\S/)) {
			$ID =~ s/\(.*//;
		    } elsif(!($ANNOT{$ID} =~ /\S/)) {
			$ID = $geneid;
			$ID =~ s/.*://;
		    } elsif(!($ANNOT{$ID} =~ /\S/)) {
			$ID = $geneid;
			$ID =~ s/.*://;
			$ID =~ s/\(.*//;
		    } else {
			$ID = $geneid;
		    }

		    if($locations eq "true") {
			print OUTFILE3 "\t$genelocation{$geneid}";
		    }
		    for($i=0; $i<$numfiles; $i++) {
			$X = $profile_max{$geneid}[$i] - $profile_min{$geneid}[$i];
			print OUTFILE3 "\t$X";
		    }
		    if($ANNOT{$ID} =~ /\S/) {
			print OUTFILE3 "\t$ANNOT{$ID}";
		    }
		    print OUTFILE3 "\n";
		}
	    }
	}
	if($sort_decreasing eq "false") {
	    foreach $geneid (sort {$sort_hash1{$a}<=>$sort_hash1{$b}} keys %genelocation) {
		$IDout = $geneid;
		$IDout =~ s/::::/, /g;
		$IDout =~ s/_genes//g;
		print OUTFILE1 "$IDout";

		$ID = $geneid;
		if(!($ANNOT{$ID} =~ /\S/)) {
		    $ID =~ s/\(.*//;
		} elsif(!($ANNOT{$ID} =~ /\S/)) {
		    $ID = $geneid;
		    $ID =~ s/.*://;
		} elsif(!($ANNOT{$ID} =~ /\S/)) {
		    $ID = $geneid;
		    $ID =~ s/.*://;
		    $ID =~ s/\(.*//;
		} else {
		    $ID = $geneid;
		}

		if($locations eq "true") {
		    print OUTFILE1 "\t$genelocation{$geneid}";
		}
		for($i=0; $i<$numfiles; $i++) {
		    print OUTFILE1 "\t$profile_min{$geneid}[$i]";
		}
		if($ANNOT{$ID} =~ /\S/) {
		    print OUTFILE1 "\t$ANNOT{$ID}";
		}
		print OUTFILE1 "\n";
	    }
	    foreach $geneid (sort {$sort_hash2{$a}<=>$sort_hash2{$b}} keys %genelocation) {
		$IDout = $geneid;
		$IDout =~ s/::::/, /g;
		$IDout =~ s/_genes//g;
		print OUTFILE2 "$IDout";

		$ID = $geneid;
		if(!($ANNOT{$ID} =~ /\S/)) {
		    $ID =~ s/\(.*//;
		} elsif(!($ANNOT{$ID} =~ /\S/)) {
		    $ID = $geneid;
		    $ID =~ s/.*://;
		} elsif(!($ANNOT{$ID} =~ /\S/)) {
		    $ID = $geneid;
		    $ID =~ s/.*://;
		    $ID =~ s/\(.*//;
		} else {
		    $ID = $geneid;
		}

		if($locations eq "true") {
		    print OUTFILE2 "\t$genelocation{$geneid}";
		}
		for($i=0; $i<$numfiles; $i++) {
		    print OUTFILE2 "\t$profile_max{$geneid}[$i]";
		}
		if($ANNOT{$ID} =~ /\S/) {
		    print OUTFILE2 "\t$ANNOT{$ID}";
		}
		print OUTFILE2 "\n";
	    }
	    if($writediff eq "true") {
		foreach $geneid (sort {$sort_hash1{$a}<=>$sort_hash1{$b}} keys %genelocation) {
		    $IDout = $geneid;
		    $IDout =~ s/::::/, /g;
		    $IDout =~ s/_genes//g;
		    print OUTFILE3 "$IDout";

		    $ID = $geneid;
		    if(!($ANNOT{$ID} =~ /\S/)) {
			$ID =~ s/\(.*//;
		    } elsif(!($ANNOT{$ID} =~ /\S/)) {
			$ID = $geneid;
			$ID =~ s/.*://;
		    } elsif(!($ANNOT{$ID} =~ /\S/)) {
			$ID = $geneid;
			$ID =~ s/.*://;
			$ID =~ s/\(.*//;
		    } else {
			$ID = $geneid;
		    }

		    if($locations eq "true") {
			print OUTFILE3 "\t$genelocation{$geneid}";
		    }
		    for($i=0; $i<$numfiles; $i++) {
			$X = $profile_max{$geneid}[$i] - $profile_min{$geneid}[$i];
			print OUTFILE3 "\t$X";
		    }
		    if($ANNOT{$ID} =~ /\S/) {
			print OUTFILE3 "\t$ANNOT{$ID}";
		    }
		    print OUTFILE3 "\n";
		}
	    }
	}
    } else {
	foreach $geneid (sort {cmpChrs($genelocation{$a},$genelocation{$b})} keys %genelocation) {
	    $IDout = $geneid;
	    $IDout =~ s/::::/, /g;
	    $IDout =~ s/_genes//g;
	    print OUTFILE1 "$IDout";
	    print OUTFILE2 "$IDout";
	    if($writediff eq "true") {
		print OUTFILE3 "$IDout";
	    }
	    $ID = $geneid;
	    if(!($ANNOT{$ID} =~ /\S/)) {
		$ID =~ s/\(.*//;
	    } elsif(!($ANNOT{$ID} =~ /\S/)) {
		$ID = $geneid;
		$ID =~ s/.*://;
	    } elsif(!($ANNOT{$ID} =~ /\S/)) {
		$ID = $geneid;
		$ID =~ s/.*://;
		$ID =~ s/\(.*//;
	    } else {
		$ID = $geneid;
	    }

	    if($locations eq "true") {
		print OUTFILE1 "\t$genelocation{$geneid}";
		print OUTFILE2 "\t$genelocation{$geneid}";
		if($writediff eq "true") {
		    print OUTFILE3 "\t$genelocation{$geneid}";
		}
	    }
	    for($i=0; $i<$numfiles; $i++) {
		print OUTFILE1 "\t$profile_min{$geneid}[$i]";
		print OUTFILE2 "\t$profile_max{$geneid}[$i]";
		if($writediff eq "true") {
		    $X = $profile_max{$geneid}[$i] - $profile_min{$geneid}[$i];
		    print OUTFILE3 "\t$X";
		}
	    }
	    if($ANNOT{$ID} =~ /\S/) {
		print OUTFILE1 "\t$ANNOT{$ID}";
		print OUTFILE2 "\t$ANNOT{$ID}";
		if($writediff eq "true") {
		    print OUTFILE3 "\t$ANNOT{$ID}";
		}
	    }
	    print OUTFILE1 "\n";
	    print OUTFILE2 "\n";
	    if($writediff eq "true") {
		print OUTFILE3 "\n";
	    }
	}
    }
}

if($exonsonly eq "true" || $featuresonly eq "true") {
    $sort = "false";
    if($sort1 eq "true") {
	foreach $exonid (keys %exon_min) {
	    $sort_hash1{$exonid} = $exon_min{$exonid}[$sortcol];
	    $sort_hash2{$exonid} = $exon_min{$exonid}[$sortcol];
	}
	$sort = "true";
    }
    if($sort2 eq "true") {
	foreach $exonid (keys %exon_max) {
	    $sort_hash1{$exonid} = $exon_max{$exonid}[$sortcol];
	    $sort_hash2{$exonid} = $exon_max{$exonid}[$sortcol];
	}
	$sort = "true";
    }
    if($sort3 eq "true") {
	foreach $exonid (keys %exon_min) {
	    $sort_hash1{$exonid} = $exon_min{$exonid}[$sortcol];
	    $sort_hash2{$exonid} = $exon_max{$exonid}[$sortcol];
	}
	$sort = "true";
    }
    if($sort eq "true") {
	if($sort_decreasing eq "true") {
	    foreach $exonid (sort {$sort_hash1{$b}<=>$sort_hash1{$a}} keys %sort_hash1) {
		if($simple eq "false") {
		    print OUTFILE1 "$exonid\tEXON";
		} else {
		    print OUTFILE1 "$exonid";
		}
		for($i=0; $i<$numfiles; $i++) {
		    print OUTFILE1 "\t$exon_min{$exonid}[$i]";
		}
		print OUTFILE1 "\n";
	    }
	    foreach $exonid (sort {$sort_hash2{$b}<=>$sort_hash2{$a}} keys %sort_hash2) {
		if($simple eq "false") {
		    print OUTFILE2 "$exonid\tEXON";
		} else {
		    print OUTFILE2 "$exonid";
		}
		for($i=0; $i<$numfiles; $i++) {
		    print OUTFILE2 "\t$exon_max{$exonid}[$i]";
		}
		print OUTFILE2 "\n";
	    }
	    if($writediff eq "true") {
		foreach $exonid (sort {$sort_hash2{$b}<=>$sort_hash2{$a}} keys %sort_hash2) {
		    if($simple eq "false") {
			print OUTFILE3 "$exonid\tEXON";
		    } else {
			print OUTFILE3 "$exonid";
		    }
		    for($i=0; $i<$numfiles; $i++) {
			$X = $exon_max{$exonid}[$i] - $exon_min{$exonid}[$i];
			print OUTFILE3 "\t$X";
		    }
		    print OUTFILE3 "\n";
		}
	    }
	}
	if($sort_decreasing eq "false") {
	    foreach $exonid (sort {$exon_hash1{$a}<=>$exon_hash1{$b}} keys %sort_hash1) {
		if($simple eq "false") {
		    print OUTFILE1 "$exonid\tEXON";
		} else {
		    print OUTFILE1 "$exonid";
		}
		for($i=0; $i<$numfiles; $i++) {
		    print OUTFILE1 "\t$exon_min{$exonid}[$i]";
		}
		print OUTFILE1 "\n";
	    }
	    foreach $exonid (sort {$exon_hash2{$a}<=>$exon_hash2{$b}} keys %sort_hash2) {
		if($simple eq "false") {
		    print OUTFILE2 "$exonid\tEXON";
		} else {
		    print OUTFILE2 "$exonid";
		}
		for($i=0; $i<$numfiles; $i++) {
		    print OUTFILE2 "\t$exon_max{$exonid}[$i]";
		}
		print OUTFILE2 "\n";
	    }
	    if($writediff eq "true") {
		foreach $exonid (sort {$exon_hash2{$a}<=>$exon_hash2{$b}} keys %sort_hash2) {
		    if($simple eq "false") {
			print OUTFILE3 "$exonid\tEXON";
		    } else {
			print OUTFILE3 "$exonid";
		    }
		    for($i=0; $i<$numfiles; $i++) {
			$X = $exon_max{$exonid}[$i] - $exon_min{$exonid}[$i];
			print OUTFILE3 "\t$X";
		    }
		    print OUTFILE3 "\n";
		}
	    }
	}
    }
    if($sort eq "false") {
	foreach $exonid (sort {cmpChrs($exonlocation{$a},$exonlocation{$b})} keys %exon_min) {
	    if($simple eq "false") {
		print OUTFILE1 "$exonid\tEXON";
		print OUTFILE2 "$exonid\tEXON";
		if($writediff eq "true") {
		    print OUTFILE3 "$exonid\tEXON";
		}
	    } else {
		print OUTFILE1 "$exonid";
		print OUTFILE2 "$exonid";
		if($writediff eq "true") {
		    print OUTFILE3 "$exonid";
		}
	    }
	    for($i=0; $i<$numfiles; $i++) {
		print OUTFILE1 "\t$exon_min{$exonid}[$i]";
		print OUTFILE2 "\t$exon_max{$exonid}[$i]";
		if($writediff eq "true") {
		    print OUTFILE3 "\t$exon_max{$exonid}[$i]";
		}
	    }
	    print OUTFILE1 "\n";
	    print OUTFILE2 "\n";
	    if($writediff eq "true") {
		print OUTFILE3 "\n";
	    }
	}
    }
}

if($intronsonly eq "true" || $featuresonly eq "true") {
    $sort = "false";
    if($sort1 eq "true") {
	foreach $intronid (keys %intron_min) {
	    $sort_hash1{$intronid} = $intron_min{$intronid}[$sortcol];
	    $sort_hash2{$intronid} = $intron_min{$intronid}[$sortcol];
	}
	$sort = "true";
    }
    if($sort2 eq "true") {
	foreach $intronid (keys %intron_max) {
	    $sort_hash1{$intronid} = $intron_max{$intronid}[$sortcol];
	    $sort_hash2{$intronid} = $intron_max{$intronid}[$sortcol];
	}
	$sort = "true";
    }
    if($sort3 eq "true") {
	foreach $intronid (keys %intron_min) {
	    $sort_hash1{$intronid} = $intron_min{$intronid}[$sortcol];
	    $sort_hash2{$intronid} = $intron_max{$intronid}[$sortcol];
	}
	$sort = "true";
    }
    if($sort eq "true") {
	if($sort_decreasing eq "true") {
	    foreach $intronid (sort {$sort_hash1{$b}<=>$sort_hash1{$a}} keys %sort_hash1) {
		if($simple eq "false") {
		    print OUTFILE1 "$intronid\tINTRON";
		} else {
		    print OUTFILE1 "$intronid";
		}
		for($i=0; $i<$numfiles; $i++) {
		    print OUTFILE1 "\t$intron_min{$intronid}[$i]";
		}
		print OUTFILE1 "\n";
	    }
	    foreach $intronid (sort {$sort_hash2{$b}<=>$sort_hash2{$a}} keys %sort_hash2) {
		if($simple eq "false") {
		    print OUTFILE2 "$intronid\tINTRON";
		} else {
		    print OUTFILE2 "$intronid";
		}
		for($i=0; $i<$numfiles; $i++) {
		    print OUTFILE2 "\t$intron_max{$intronid}[$i]";
		}
		print OUTFILE2 "\n";
	    }
	    if($writediff eq "true") {
		foreach $intronid (sort {$sort_hash2{$b}<=>$sort_hash2{$a}} keys %sort_hash2) {
		    if($simple eq "false") {
			print OUTFILE3 "$intronid\tINTRON";
		    } else {
			print OUTFILE3 "$intronid";
		    }
		    for($i=0; $i<$numfiles; $i++) {
			$X = $intron_max{$intronid}[$i] - $intron_min{$intronid}[$i];
			print OUTFILE3 "\t$X";
		    }
		    print OUTFILE3 "\n";
		}
	    }
	}
	if($sort_decreasing eq "false") {
	    foreach $intronid (sort {$intron_hash1{$a}<=>$intron_hash1{$b}} keys %sort_hash1) {
		if($simple eq "false") {
		    print OUTFILE1 "$intronid\tINTRON";
		} else {
		    print OUTFILE1 "$intronid";
		}
		for($i=0; $i<$numfiles; $i++) {
		    print OUTFILE1 "\t$intron_min{$intronid}[$i]";
		}
		print OUTFILE1 "\n";
	    }
	    foreach $intronid (sort {$intron_hash2{$a}<=>$intron_hash2{$b}} keys %sort_hash2) {
		if($simple eq "false") {
		    print OUTFILE2 "$intronid\tINTRON";
		} else {
		    print OUTFILE2 "$intronid";
		}
		for($i=0; $i<$numfiles; $i++) {
		    print OUTFILE2 "\t$intron_max{$intronid}[$i]";
		}
		print OUTFILE2 "\n";
	    }
	    if($writediff eq "true") {
		foreach $intronid (sort {$intron_hash2{$a}<=>$intron_hash2{$b}} keys %sort_hash2) {
		    if($simple eq "false") {
			print OUTFILE3 "$intronid\tINTRON";
		    } else {
			print OUTFILE3 "$intronid";
		    }
		    for($i=0; $i<$numfiles; $i++) {
			$X = $intron_max{$intronid}[$i] - $intron_min{$intronid}[$i];
			print OUTFILE3 "\t$X";
		    }
		    print OUTFILE3 "\n";
		}
	    }
	}
    }
    if($sort eq "false") {
	foreach $intronid (sort {cmpChrs($intronlocation{$a},$intronlocation{$b})} keys %intron_min) {
	    if($simple eq "false") {
		print OUTFILE1 "$intronid\tINTRON";
		print OUTFILE2 "$intronid\tINTRON";
		if($writediff eq "true") {
		    print OUTFILE3 "$intronid\tINTRON";
		}
	    } else {
		print OUTFILE1 "$intronid";
		print OUTFILE2 "$intronid";
		if($writediff eq "true") {
		    print OUTFILE3 "$intronid";
		}
	    }
	    for($i=0; $i<$numfiles; $i++) {
		print OUTFILE1 "\t$intron_min{$intronid}[$i]";
		print OUTFILE2 "\t$intron_max{$intronid}[$i]";
		if($writediff eq "true") {
		    $X = $intron_max{$intronid}[$i] - $intron_min{$intronid}[$i];
		    print OUTFILE3 "\t$X";
		}
	    }
	    print OUTFILE1 "\n";
	    print OUTFILE2 "\n";
	    if($writediff eq "true") {
		print OUTFILE3 "\n";
	    }
	}
    }
}

sub cmpChrs () {
    $A2_c = lc($b);
    $B2_c = lc($a);

    $A2_c =~ /^(.*):(\d+)-(\d+)$/;
    $a2_c = $1;
    $startcoord_a = $2;
    $endcoord_a = $3;

    $B2_c =~ /^(.*):(\d+)-(\d+)$/;
    $b2_c = $1;
    $startcoord_b = $2;
    $endcoord_b = $3;

    if($a2_c eq $b2_c) {
	if($startcoord_a < $startcoord_b) {
	    return 1;
	}
	if($startcoord_b < $startcoord_a) {
	    return -1;
	}
	if($startcoord_a == $startcoord_b) {
	    if($endcoord_a < $endcoord_b) {
		return 1;
	    }
	    if($endcoord_b < $endcoord_a) {
		return -1;
	    }
	    if($endcoord_a == $endcoord_b) {
		return 1;
	    }
	}
    }

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
	$a2_roman = $1;
	$b2_c =~ /chr([ivx]+)/;
	$b2_roman = $1;
	$a2_arabic = arabic($a2_roman);
    	$b2_arabic = arabic($b2_roman);
	if($a2_arabic > $b2_arabic) {
	    return -1;
	} 
	if($a2_arabic < $b2_arabic) {
	    return 1;
	}
	if($a2_arabic == $b2_arabic) {
	    $tempa = $a2_c;
	    $tempb = $b2_c;
	    $tempa =~ s/chr([ivx]+)//;
	    $tempb =~ s/chr([ivx]+)//;
	    undef %temphash;
	    $temphash{$tempa}=1;
	    $temphash{$tempb}=1;
	    foreach $tempkey (sort {cmpChrs($a,$b)} keys %temphash) {
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
    if($b2_c =~ /m$/ && $a2_c =~ /vi+/) {
	return 1;
    }
    if($a2_c =~ /m$/ && $b2_c =~ /vi+/) {
	return -1;
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
        $numa = $1;
        if($b2_c =~ /chr(\d+)/) {
            $numb = $1;
            if($numa < $numb) {return 1;}
	    if($numa > $numb) {return -1;}
	    if($numa == $numb) {
		$tempa = $a2_c;
		$tempb = $b2_c;
		$tempa =~ s/chr\d+//;
		$tempb =~ s/chr\d+//;
		undef %temphash;
		$temphash{$tempa}=1;
		$temphash{$tempb}=1;
		foreach $tempkey (sort {cmpChrs($a,$b)} keys %temphash) {
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
        $letter_a = $1;
        if($b2_c =~ /chr([a-z]+)/) {
            $letter_b = $1;
            if($letter_a lt $letter_b) {return 1;}
	    if($letter_a gt $letter_b) {return -1;}
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
    if($a2_c le $b2_c) {
	return 1;
    }
    if($b2_c le $a2_c) {
	return -1;
    }


    return 1;
}

sub isroman($) {
    $arg = shift;
    $arg ne '' and
      $arg =~ /^(?: M{0,3})
                (?: D?C{0,3} | C[DM])
                (?: L?X{0,3} | X[LC])
                (?: V?I{0,3} | I[VX])$/ix;
}

sub arabic($) {
    $arg = shift;
    %roman2arabic = qw(I 1 V 5 X 10 L 50 C 100 D 500 M 1000);
    %roman_digit = qw(1 IV 10 XL 100 CD 1000 MMMMMM);
    @figure = reverse sort keys %roman_digit;
    $roman_digit{$_} = [split(//, $roman_digit{$_}, 2)] foreach @figure;
    isroman $arg or return undef;
    ($last_digit) = 1000;
    $arabic=0;
    ($arabic);
    foreach (split(//, uc $arg)) {
        ($digit) = $roman2arabic{$_};
        $arabic -= 2 * $last_digit if $last_digit < $digit;
        $arabic += ($last_digit = $digit);
    }
    $arabic;
}

sub Roman($) {
    $arg = shift;
    %roman2arabic = qw(I 1 V 5 X 10 L 50 C 100 D 500 M 1000);
    %roman_digit = qw(1 IV 10 XL 100 CD 1000 MMMMMM);
    @figure = reverse sort keys %roman_digit;
    $roman_digit{$_} = [split(//, $roman_digit{$_}, 2)] foreach @figure;
    0 < $arg and $arg < 4000 or return undef;
    $roman="";
    ($x, $roman);
    foreach (@figure) {
        ($digit, $i, $v) = (int($arg / $_), @{$roman_digit{$_}});
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

sub roman($) {
    lc Roman shift;
}
