$|=1;
$timestart = time();
if(@ARGV < 2) {
    die "
Usage: rum2cov.pl <rum file> <coverage file> [option]

Where <rum file> is the *sorted* RUM_Unique or RUM_NU file.
      <coverage file> is the name of the output file, should end in .cov

Option:
       -name x   : the name of the track

If it's not sorted, first run sort_RUM_by_location.pl to sort,
and *do not* use the -separate option.

";
}

# option not implemented:
#       -strand s : s=p to use just + strand reads, s=m to use just - strand.

print "\nMaking coverage plot $ARGV[1]...\n\n";

$infile = $ARGV[0];
$outfile = $ARGV[1];
$name = $infile . " Coverage";
$strandspecific="false";
$strand = "";
for($i=2; $i<@ARGV; $i++) {
    $optionrecognized = 0;
    if($ARGV[$i] eq "-name") {
	$name = $ARGV[$i+1];
	$i++;
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-strand") {
	$strand = $ARGV[$i+1];
	$strandspecific="true";
	$i++;
	if(!($strand eq 'p' || $strand eq 'm')) {
	    die "\nERROR: in script rum2cov.pl: -strand must equal either 'p' or 'm', not '$strand'\n\n";
	}
	$optionrecognized = 1;
    }
    if($optionrecognized == 0) {
	die "\nERROR: in script rum2cov.pl: option '$ARGV[$i]' not recognized\n";
    }
}


open(INFILE, $infile) or die "ERROR: in script rum2cov.pl: could not open the file '$infile' for reading";
open(OUTFILE, ">$outfile") or die "ERROR: in script rum2cov.pl: could not open the file '$outfile' for writing";
print OUTFILE "track type=bedGraph name=\"$name\" description=\"$name\" visibility=full color=255,0,0 priority=10\n";

$flag = 0;
&getStartEndandSpans_of_nextline();
$current_chr = $chr;
$current_loc = $start-1;
$current_cov = 0;
$first_span_on_chr = 1;
$end_max = 0;
$span_ended = 1;
$prev_end = $end+2;
while($flag < 2) {
    if($flag == 1) {
	$flag = 2;
    }
    if($chr eq $current_chr) {
	@S = split(/, /, $spans);
	for($i=0; $i<@S; $i++) {
	    @b = split(/-/, $S[$i]);
	    for($j=$b[0]; $j<=$b[1]; $j++) {
		$position_coverage{$j}++;
	    }
	}
	if($start > $current_loc) {
	    if($prev_end < $start) {
		$M = $prev_end;
	    } else {
		$M = $start;
	    }
	    for($j=$current_loc+1; $j<$M; $j++) {
		if($position_coverage{$j}+0 != $current_cov) { # span ends here
		    if($current_cov > 0) {
			$k=$j-1;
			print OUTFILE "\t$k\t$current_cov\n";  # don't adjust the right point because half-open
			$span_ended = 1;
		    }
		    $current_cov = $position_coverage{$j}+0;
		    if($current_cov > 0) { # start a new span
			$k = $j-1; # so as to be half zero based
			print OUTFILE "$chr\t$k";
			$span_ended = 0;
		    }
		}
		delete $position_coverage{$j};
	    }
	    $current_loc = $start - 1;
	    if($end+2 >= $prev_end) {
		$prev_end = $end + 2;
	    }
	}
	&getStartEndandSpans_of_nextline();
    } else {
	for($j=$current_loc+1; $j<=$end_max; $j++) {
	    if($position_coverage{$j}+0 != $current_cov) { # span ends here
		if($current_cov > 0) {
		    $k=$j-1;
		    print OUTFILE "\t$k\t$current_cov\n";  # don't adjust the right point because half-open
		    $span_ended = 1;
		}
		$current_cov = $position_coverage{$j}+0;
		if($current_cov > 0) { # start a new span
		    $k = $j-1; # so as to be half zero based
		    print OUTFILE "$chr_prev\t$k";
		    $span_ended = 0;
		}
	    }
	}
	if($span_ended == 0) {
	    print OUTFILE "\t$end_max\t$current_cov\n";  # don't adjust the right point because half-open
	}
	undef %position_coverage;
	$current_chr = $chr;
	$current_loc = $start-1;
	$current_cov = 0;
	$end_max = 0;
	$prev_end = $end+2;
    }
}

$timeend = time();
$timelapse = $timeend - $timestart;
if($timelapse < 0) {
    $timelapse = 0;
}
if($timelapse < 60) {
    print "\nIt took $timelapse seconds to create the coverage file $outfile.\n\n";
}
else {
    $sec = $timelapse % 60;
    $min = int($timelapse / 60);
    if($min > 1 && $sec > 1) {
	print "\nIt took $min minutes, $sec seconds to create the coverage file $outfile.\n\n";
    }
    if($min == 1 && $sec > 1) {
	print "\nIt took $min minute, $sec seconds to create the coverage file $outfile.\n\n";
    }
    if($min > 1 && $sec == 1) {
	print "\nIt took $min minutes, $sec second to create the coverage file $outfile.\n\n";
    }
    if($min == 1 && $sec == 1) {
	print "\nIt took $min minute, $sec second to create the coverage file $outfile.\n\n";
    }
}

sub getStartEndandSpans_of_nextline () {
    $line = <INFILE>;
    chomp($line);
    if($end > $end_max) {
	$end_max = $end;
    }
    $chr_prev = $chr;
    $start_prev = $start;
    if($line eq '') {
	$flag = 1;
	for($tryagain=0; $tryagain<10; $tryagain++) {
	    $line = <INFILE>;
	    chomp($line);
	    if($line ne '') {
		$tryagain = 10;
		$flag = 0;
	    }
	}
	if($flag == 1) {
	    $chr = "";
	    return;
	}
    }
    @a_g = split(/\t/,$line);
    $chr = $a_g[1];
    $a_g[2] =~ /^(\d+)-/;
    $start = $1;
    $spans = $a_g[2];
    if($a_g[0] =~ /a/) {
	$a_g[0] =~ /(\d+)/;
	$seqnum1 = $1;
	$line2 = <INFILE>;
	chomp($line2);
	@b_g = split(/\t/,$line2);
	$b_g[0] =~ /(\d+)/;
	$seqnum2 = $1;
	if($seqnum1 == $seqnum2 && $b_g[0] =~ /b/) {
	    if($a_g[3] eq "+") {
		$b_g[2] =~ /-(\d+)$/;
		$end = $1;
		$spans = $spans . ", " . $b_g[2];
	    } else {
		$b_g[2] =~ /^(\d+)-/;
		$start = $1;
		$a_g[2] =~ /-(\d+)$/;
		$end = $1;
		$spans = $b_g[2] . ", " . $spans;
	    }
	} else {
	    $a_g[2] =~ /-(\d+)$/;
	    $end = $1;
	    # reset the file handle so the last line read will be read again
	    $len_g = -1 * (1 + length($line2));
	    seek(INFILE, $len_g, 1);
	}
    } else {
	$a_g[2] =~ /-(\d+)$/;
	$end = $1;
    }
    if($chr ne $chr_prev) {
	$chromosomes_finished{$chr_prev}++;
    }
    if($chromosomes_finished{$chr}+0>0) {
	die "\nERROR: in script rum2cov.pl: It appears your file '$infile' is not sorted.\nUse sort_RUM_by_location.pl to sort it.\n\n";
    }
    if($chr eq $chr_prev && $start < $start_prev) {
	die "\nERROR: in script rum2cov.pl: It appears your file '$infile' is not sorted.\nUse sort_RUM_by_location.pl to sort it.\n\n";
    }
}
