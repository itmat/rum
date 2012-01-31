
if(@ARGV < 2) {
    die "
Usage: get_RUM_reads_from_span.pl <chr> <start> <end> <chrdir> [options] | less -S

This script gets all the reads from a RUM_Unique or RUM_NU
file and prints them out in a multiple alignment.  The
consensus sequence is printed at the bottom.

Options: -v : output in vertical mode
         -h : output in horizontal mode
  * Note: one, or both, of -v or -h must be specified.

<chrdir> is a directory with a RUM file that has
been broken into individual chromosomes (this is done for
efficiency).  To do the breaking up for 'RUM_Unique', make
a directory, say 'chrdir' and run the following:
> perl get_RUM_reads_from_span.pl RUM_Unique -prepare chrdir
After that finishes you can run the program using the
normal four arguments.

Output is piped to 'less -S' so it's easier to read, but
you can also output to a file.  If you name the file with
suffix '.txt' and open it in a web browser it will display
pretty nicely.  You might want to zoom way out to see it
better, - on Firefox control-<minus-sign> shrinks the font
and control-<plus sign> increases it

";
}

$infile = $ARGV[0];
if($ARGV[1] eq "-prepare") {
    $individual_file_dir = $ARGV[2];
    open(INFILE, $ARGV[0]);
    while($line = <INFILE>) {
	chomp($line);
	@a = split(/\t/,$line);
	$chr = $a[1];
	if(!(defined $chromosomes{$chr})) {
	    $chromosomes{$chr}++;
	    open $F1{$chr}, ">" . "$individual_file_dir/" . $chr;
	}
	$FF = $F1{$chr};
	print $FF "$line\n";
    }
    foreach $chr (keys %F1) {
	close($F1{$chr});
    }
    exit();
}

$CHR = $ARGV[0];
$START = $ARGV[1];
$END = $ARGV[2];
$individual_file_dir = $ARGV[3];

$horizontal = "false";
$vertical = "false";
for($i=4; $i<@ARGV; $i++) {
    $optionrecognized = 0;
    if($ARGV[$i] eq "-v") {
	$vertical = "true";
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-h") {
	$horizontal = "true";
	$optionrecognized = 1;
    }
    if($optionrecognized == 0) {
	die "\nERROR: option '$ARGV[$i]' not recognized\n";
    }
}
if($vertical eq "false" && $horizontal eq "false") {
    die "\nError: one of -v or -h must be specified\n\n";
}

open(INFILE, "$individual_file_dir/$CHR");
$hit=0;
$upstream_limit=1000000000000;
$downstream_limit=0;
$maxidlength=0;
print STDERR "searching '$infile' for reads..\n";
while($line = <INFILE>) {
    chomp($line);
    @a = split(/\t/,$line);
    $coords = $a[2];
    $strand = $a[3];
    $seq = $a[4];
    $coords =~ /^(\d+)/;
    $start = $1;
    $coords =~ /(\d+)$/;
    $end = $1;
    $id = $a[0];
    if(length($id)>$maxidlength) {
	$maxidlength = length($id);
    }
    if($end >= $START && $start <= $END) {
	$hits[$hit][0] = $coords;
	$hits[$hit][1] = $strand;
	while($seq =~ /\+/) {
	    $seq =~ s/^([^+]+)\+[^+]+\+/$1/;
	}
	$hits[$hit][2] = $seq;
	$hits[$hit][3] = $id;
	$hit++;
	if($start < $upstream_limit) {
	    $upstream_limit = $start;
	}
	if($end > $downstream_limit) {
	    $downstream_limit = $end;
	}
    }
}
close(INFILE);

print STDERR "finding gaps..\n";
$numhits = $hit;
for($i=0; $i<$numhits; $i++) {
    @C = split(/, /, $hits[$i][0]);
    for($j=0; $j<@C; $j++) {
	@b = split(/-/, $C[$j]);
	$COORDS[$j][0] = $b[0];
	$COORDS[$j][1] = $b[1];
    }
    $coord_span_cnt = 0;
    for($j=0; $j<@COORDS; $j++) {
	for($position=$COORDS[$j][0]; $position<=$COORDS[$j][1]; $position++) {
	    $data_exists{$position}++;
	}
    }
}

$gap = 0;
open(LOG, ">log.txt");
for($j=$upstream_limit; $j<=$downstream_limit; $j++) {
    print LOG "$j\t$data_exists{$j}\n";
    if(!(exists $data_exists{$j}) && $gap == 0) {
	print LOG "here 1\n";
	$gap_start{$j}++;
	$gap = 1;
	$j2 = $j;
    } elsif((exists $data_exists{$j}) && $gap == 1) {
	    print LOG "here 2\n";
	    $gap_end{$j2}=$j;
	    $gap = 0;
    }
}
foreach $key (sort {$a<=>$b} keys %gap_start) {
    print LOG "$key: $gap_start{$key} : $gap_end{$key}\n";
}
close(LOG);
$gapnum=0;
print STDERR "parsing $numhits reads...\n";
for($i=0; $i<$numhits; $i++) {
    if($numhits <= 1000 && $i % 100 == 0) {
	print STDERR "done $i\n";
    }
    if($numhits >= 1600 && $i % 500 == 0) {
	print STDERR "done $i\n";
    }
    @C = split(/, /, $hits[$i][0]);
    $strand = $hits[$i][1];
    $id = $hits[$i][3];
    $whitespace_length = $maxidlength - length($id);
    $output[$i] = $id;
    for($k=0; $k<$whitespace_length+1; $k++) {
	$output[$i] = $output[$i] . " ";
    }
    @S = split(/:/, $hits[$i][2]);
    undef @SEQ;
    undef @COORDS;
    for($j=0; $j<@C; $j++) {
	@b = split(/-/, $C[$j]);
	$COORDS[$j][0] = $b[0];
	$COORDS[$j][1] = $b[1];
	@{$SEQ[$j]} = split(//, $S[$j]);
    }
    $coord_span_cnt = 0;
    $run_of_spaces_start=0;
    for($j=$upstream_limit; $j<=$COORDS[@COORDS-1][1]; $j++) {
	if(exists $gap_start{$j}){
	    $gap_length = $gap_end{$j} - $j;
	    $GL = format_large_int($gap_length);
	    if($i == 0) {
		$gaplength[$gapnum] = $GL;
		$gapnum++;
	    }
	    if($run_of_spaces_start == 1) {
		$run_of_spaces = " " x $run_of_spaces_length;
		$output[$i] = $output[$i] . $run_of_spaces;
		$run_of_spaces_start = 0;
	    }
	    $output[$i] = $output[$i] . "  <-  $GL bp gap ->  ";
	    $j = $gap_end{$j};
	} else {
	    if($j < $COORDS[$coord_span_cnt][0]) {
		if($run_of_spaces_start == 1) {
		    $run_of_spaces_length++;
		}
		if($run_of_spaces_start == 0) {
		    $run_of_spaces_length = 1;
		    $run_of_spaces_start = 1;
		}
	    }
	    if($j >= $COORDS[$coord_span_cnt][0] && $j <= $COORDS[$coord_span_cnt][1]) {
		if($run_of_spaces_start == 1) {
		    $run_of_spaces = " " x $run_of_spaces_length;
		    $output[$i] = $output[$i] . $run_of_spaces;
		    $run_of_spaces_start = 0;
		}
		$k = $j - $COORDS[$coord_span_cnt][0];
		$BASE{$j}{$SEQ[$coord_span_cnt][$k]}++;
		$output[$i] = $output[$i] . $SEQ[$coord_span_cnt][$k];
	    }
	    if($j == $COORDS[$coord_span_cnt][1]) {
		$coord_span_cnt++;
	    }
	}
    }
}
for($i=0; $i<$maxidlength+1; $i++) {
    $output[$numhits] = $output[$numhits] . " ";
}
print STDERR "creating output...\n";
for($j=$upstream_limit; $j<=$downstream_limit; $j++) {
    if(exists $gap_start{$j}){
	$gap_length = $gap_end{$j} - $j;
	$GL = format_large_int($gap_length);
	$output[$numhits] = $output[$numhits] . "------------------";
	for($i=0;$i<length($GL);$i++) {
	    $output[$numhits] = $output[$numhits] . "-";
	}
	$j = $gap_end{$j};
    } else {
	$output[$numhits] = $output[$numhits] . "-";
    }
}

for($i=0; $i<$maxidlength+1; $i++) {
    $output[$numhits+1] = $output[$numhits+1] . " ";
}
print STDERR "creating consensus seq...\n";
for($j=$upstream_limit; $j<=$downstream_limit; $j++) {
    if(exists $gap_start{$j}){
	$gap_length = $gap_end{$j} - $j;
	$GL = format_large_int($gap_length);
	$output[$numhits+1] = $output[$numhits+1] . "  <-  $GL bp gap ->  ";
	$j = $gap_end{$j};
    } else {
	$consensus = "A";
	$A = $BASE{$j}{"A"};
	$max = $A;
	$C = $BASE{$j}{"C"};
	if($C > $max) {
	    $consensus = "C";
	    $max = $C;
	}
	$G = $BASE{$j}{"G"};
	if($G > $max) {
	    $consensus = "G";
	    $max = $G;
	}
	$T = $BASE{$j}{"T"};
	if($T > $max) {
	    $consensus = "T";
	    $max = $T;
	}
	$N = $BASE{$j}{"N"};
	if($N > $max) {
	    $consensus = "N";
	    $max = $N;
	}
	$output[$numhits+1] = $output[$numhits+1] . $consensus;
    }
}
for($i=0; $i<$maxidlength+1; $i++) {
    $output[$numhits+2] = $output[$numhits+2] . " ";
}

for($j=$upstream_limit; $j<=$downstream_limit; $j++) {
    if(exists $gap_start{$j}){
	$gap_length = $gap_end{$j} - $j;
	$GL = format_large_int($gap_length);
	$output[$numhits+2] = $output[$numhits+2] . "------------------";
	for($i=0;$i<length($GL);$i++) {
	    $output[$numhits+2] = $output[$numhits+2] . "-";
	}
	$j = $gap_end{$j};
    } else {
	$output[$numhits+2] = $output[$numhits+2] . "-";
    }
}

print STDERR "creating output matrix...\n";
$maxrowlength = 0;
for($i=0;$i<$numhits+3;$i++) {
    if($numhits <= 1000 && $i % 100 == 0) {
	print STDERR "done $i\n";
    }
    if($numhits >= 1600 && $i % 500 == 0) {
	print STDERR "done $i\n";
    }
    @{$output_matrix[$i]} = split(//, $output[$i]);
    $temp =  $output[$i];
    $temp =~ s/,//g;
    $temp =~ s/ \d+ bp gap //g;
    $temp =~ s/ <- -> /X/g;
    @{$output_matrix2[$i]} = split(//, $temp);
    if($maxrowlength < @{$output_matrix2[$i]}) {
	$maxrowlength = @{$output_matrix2[$i]};
    }
}

print STDERR "printing results...\n";

if($horizontal eq 'true') {
    for($i=0;$i<$numhits+3;$i++) {
	$N = @{$output_matrix[$i]};
	for($j=0;$j<$N;$j++) {
	    print "$output_matrix[$i][$j]";
	}
	print "\n";
    }
}

$gapnum=0;
if($vertical eq 'true') {
    for($j=$maxidlength+1;$j<$maxrowlength;$j++) {
	$row = "";
	for($i=0;$i<$numhits+3;$i++) {
	    $output_matrix2[$numhits+3-$i-1][$j] =~ s/-/|/;
	    $output_matrix2[$numhits+3-$i-1][$j] =~ s/>/v/;
	    $output_matrix2[$numhits+3-$i-1][$j] =~ s/</\^/;	    
	    if($i==0 && $output_matrix2[$numhits+1][$j] eq "X") {
		$row = $row . "GAP";
		$GL = $gaplength[$gapnum];
		$gapnum++;
		$row = $row . " $GL bp";
		$i=$numhits+3;
	    } elsif ($i==0 && $output_matrix2[$numhits+1][$j] eq " ") {
		$row = $row . "---";
		$i=$numhits+3;
	    } else {
		$row = $row . "$output_matrix2[$numhits+3-$i-1][$j]";
                if($output_matrix2[$numhits+3-$i-1][$j] eq "|") {
		    $barcount{$j}++;
		    if($barcount{$j} == 2) {
			$row = $row . " ";
		    }
                }
	    }
	}
	$row =~ s/\s*$//;
	if($row ne "||") {
	    print $row;
	    print "\n";
	}
    }
}

sub format_large_int () {
    ($int_f) = @_;
    @a_f = split(//,"$int_f");
    $j_f=0;
    $newint_f = "";
    $n_f = @a_f;
    for($i_f=$n_f-1;$i_f>=0;$i_f--) {
	$j_f++;
	$newint_f = $a_f[$i_f] . $newint_f;
	if($j_f % 3 == 0) {
	    $newint_f = "," . $newint_f;
	}
    }
    $newint_f =~ s/^,//;
    return $newint_f;
}
