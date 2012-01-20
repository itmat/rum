#!/usr/bin/perl

# Written by Gregory R. Grant
# Universiry of Pennsylvania, 2010

if(@ARGV < 1) {
    die "
Usage: fix_geneinfofile_for_neg_introns.pl <gene info file> <starts col> <ends col> <num exons col>

This script takes a UCSC gene annotation file and outputs a file that removes
introns of zero or negative length.  You'd think there shouldn't be such introns
but for some annotation sets there are.

<starts col> is the column with the exon starts, <ends col> is the column with
the exon ends.  These are counted starting from zero.  <num exons col> is the
column that has the number of exons, also counted starting from zero.  If there
is no such column, set this to -1.

This script is part of the pipeline of scripts used to create RUM indexes.
For more information see the library file: 'how2setup_genome-indexes_forPipeline.txt'.

";
}

$starts_col = $ARGV[1];
$ends_col = $ARGV[2];
$exon_count_col = $ARGV[3];

open(INFILE, $ARGV[0]);
#$line = <INFILE>;
#print $line;
while($line = <INFILE>) {
    chomp($line);
    @a = split(/\t/, $line);
    $starts = $a[$starts_col];
    $ends = $a[$ends_col];
    if(!($starts =~ /\S/)) {
	die "ERROR: the 'starts' column has empty entries\n";
    }
    if(!($ends =~ /\S/)) {
	die "ERROR: the 'ends' column has empty entries\n";
    }
    if(!($a[$exon_counts_col] =~ /\S/)) {
	die "ERROR: the 'exon counts' column has empty entries\n";
    }

    $starts =~ s/,\s*$//;
    $ends =~ s/,\s*$//;
    @S = split(/,/, $starts);
    @E = split(/,/, $ends);
    $start_string = $S[0] . ",";
    $end_string = "";
    $N = @S;
    for($i=1; $i<$N; $i++) {
        $intronlength = $S[$i] - $E[$i-1];
        $realstart = $E[$i-1] + 1;
        $realend = $S[$i];
        $length = $realend - $realstart + 1;
#       print "length = $length\n";
        if($length > 0) {
            $start_string = $start_string . $S[$i] . ",";
            $end_string = $end_string . $E[$i-1] . ",";
        }
        else {
#           print "$line\n";
	    if($exon_count_col >= 0) {
		$a[$exon_count_col]--;
	    }
        }
    }
    $end_string = $end_string . $E[$N-1] . ",";;
    $a[$starts_col] = $start_string;
    $a[$ends_col] = $end_string;
    print "$a[0]";
    for($i=1; $i<@a; $i++) {
	print "\t$a[$i]";
    }
    print "\n";
}
