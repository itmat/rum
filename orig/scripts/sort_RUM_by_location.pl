$|=1;
$timestart = time();
if(@ARGV < 2) {
    die "
Usage: sort_RUM_by_location.pl <rum file> <sorted file> [options]

Where: <rum file> is the RUM_Unique or RUM_NU file output from
       the RUM pipeline.
       <sorted file> is the name of the sorted output file

Options: -separate : Do not (necessarilly) keep forward and reverse
                     together.  By default they are kept together.

         -ram n    : the number of GB of RAM if less than 8, otherwise
                     will assume you have 8, give or take, and pray...
                     If you have some millions of reads and not at
                     least 4Gb then this is probably not going to work.

";
}

print STDERR "\n";

$separate = "false";
$ram = 8;
$infile = $ARGV[0];
$outfile = $ARGV[1];
for($i=2; $i<@ARGV; $i++) {
    $optionrecognized = 0;
    if($ARGV[$i] eq "-separate") {
	$separate = "true";
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-ram") {
	$ram = $ARGV[$i+1];
	if(!($ram =~ /^\d+$/)) {
	    die "\nError: -ram must be an integer greater than zero, you gave '$ram'.\n\n";
	} elsif($ram==0) {
	    die "\nError: -ram must be an integer greater than zero, you gave '$ram'.\n\n";
	}
	$i++;
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-name") {
	$name = $ARGV[$i+1];
	$i++;
	$optionrecognized = 1;
    }
    if($optionrecognized == 0) {
	die "\nERROR: option '$ARGV[$i]' not recognized\n";
    }
}

#print STDERR "ram = $ram\n";

if($ram >= 7) {
    $max_count_at_once = 10000000;
} elsif($ram >=6) {
    $max_count_at_once = 9000000;
} elsif($ram >=5) {
    $max_count_at_once = 7500000;
} elsif($ram >=4) {
    $max_count_at_once = 6000000;
} elsif($ram >=3) {
    $max_count_at_once = 4500000;
} elsif($ram >=2) {
    $max_count_at_once = 3000000;
} elsif($ram == 1) {
    $max_count_at_once = 1500000;
}

open(INFILE, $infile);
open(FINALOUT, ">$outfile");

while($line = <INFILE>) {
    chomp($line);
    @a = split(/\t/,$line);
    if($a[1] =~ /\S/) {
	$chr_counts{$a[1]}++;
    }
}
close(INFILE);

$cnt=0;
print "\n$infile reads per chromosome:\n\nchr_name\tnum_reads\n";
foreach $chr (sort cmpChrs keys %chr_counts) {
    $CHR[$cnt] = $chr;
    $cnt++;
    print "$chr\t$chr_counts{$chr}\n";
}
$chunk = 0;
$cnt=0;
while($cnt < @CHR) {
    $running_count = $chr_counts{$CHR[$cnt]};
    $CHUNK{$CHR[$cnt]} = $chunk;
    if($chr_counts{$CHR[$cnt]} > $max_count_at_once) { # it's bigger than $max_count_at_once all by itself..
	$CHUNK{$CHR[$cnt]} = $chunk;
	$cnt++;
	$chunk++;
	next;
    }
    $cnt++;
    while($running_count+$chr_counts{$CHR[$cnt]} < $max_count_at_once && $cnt < @CHR) {
	$running_count = $running_count + $chr_counts{$CHR[$cnt]};
	$CHUNK{$CHR[$cnt]} = $chunk;
	$cnt++;
    }
    $chunk++;
}

# DEBUG
#foreach $chr (sort cmpChrs keys %CHUNK) {
#    print STDERR "$chr\t$CHUNK{$chr}\n";
#}
# DEBUG

$numchunks = $chunk;
for($chunk=0;$chunk<$numchunks;$chunk++) {
    open $F1{$chunk}, ">" . $infile . "_sorting_tempfile." . $chunk;
}
open(INFILE, $infile);
while($line = <INFILE>) {
    chomp($line);
    @a = split(/\t/,$line);
    $FF = $F1{$CHUNK{$a[1]}};
    if($line =~ /\S/) {
	print $FF "$line\n";
    }
}
for($chunk=0;$chunk<$numchunks;$chunk++) {
    close $F1{$chunk};
}

$cnt=0;
$chunk=0;
print STDERR "\nsorting reads by chromosome and location...\n";
while($cnt < @CHR) {
    undef %chrs_current;
    undef %hash;
    $running_count = $chr_counts{$CHR[$cnt]};
    $chrs_current{$CHR[$cnt]} = 1;
    print STDERR "working on: $CHR[$cnt] ";
    if($chr_counts{$CHR[$cnt]} > $max_count_at_once) { # it's a monster chromosome, going to do it in
                                                       # pieces for fear of running out of RAM.
	$INFILE = $infile . "_sorting_tempfile." . $CHUNK{$CHR[$cnt]};
	open(INFILE, $INFILE);
	$FLAG = 0;
	$chunk_num = 0;
	while($FLAG == 0) {
	    $chunk_num++;
	    $number_so_far = 0;
	    undef %hash;
	    $chunkFLAG = 0;
	    # read in one chunk:
	    while($chunkFLAG == 0) {
		$line = <INFILE>;
		chomp($line);
		if($line eq '') {
		    $chunkFLAG = 1;
		    $FLAG = 1;
		    next;
		}
		@a = split(/\t/,$line);
		$chr = $a[1];
		$number_so_far++;
		if($number_so_far>$max_count_at_once) {
		    $chunkFLAG=1;
		}
		$a[2] =~ /^(\d+)-/;
		$start = $1;
		if($a[0] =~ /a/ && $separate eq "false") {
		    $a[0] =~ /(\d+)/;
		    $seqnum1 = $1;
		    $line2 = <INFILE>;
		    chomp($line2);
		    @b = split(/\t/,$line2);
		    $b[0] =~ /(\d+)/;
		    $seqnum2 = $1;
		    if($seqnum1 == $seqnum2 && $b[0] =~ /b/) {
			if($a[3] eq "+") {
			    $b[2] =~ /-(\d+)$/;
			    $end = $1;
			} else {
			    $b[2] =~ /^(\d+)-/;
			    $start = $1;
			    $a[2] =~ /-(\d+)$/;
			    $end = $1;
			}
 			$hash{$line . "\n" . $line2}[0] = $start;
			$hash{$line . "\n" . $line2}[1] = $end;
			$number_so_far++;
		    } else {
			$a[2] =~ /-(\d+)$/;
			$end = $1;
			# reset the file handle so the last line read will be read again
			$len = -1 * (1 + length($line2));
			seek(INFILE, $len, 1);
			$hash{$line}[0] = $start;
			$hash{$line}[1] = $end;
		    }
		} else {
		    $a[2] =~ /-(\d+)$/;
		    $end = $1;
		    $hash{$line}[0] = $start;
		    $hash{$line}[1] = $end;
		}
	    }
	    # write out this chunk sorted:
	    if($chunk_num == 1) {
		$tempfilename = $CHR[$cnt] . "_temp.0";
	    } else {
		$tempfilename = $CHR[$cnt] . "_temp.1";
	    }
#	    print "$tempfilename = $tempfilename\n";
	    open(OUTFILE,">$tempfilename");
	    foreach $line (sort {$hash{$a}[0]<=>$hash{$b}[0] || ($hash{$a}[0]==$hash{$b}[0] && $hash{$a}[1]<=>$hash{$b}[1])} keys %hash) {
		chomp($line);
		if($line =~ /\S/) {
		    print OUTFILE $line;
		    print OUTFILE "\n";
		}
	    }
	    close(OUTFILE);

	    # merge with previous chunk (if necessary):
#	    print "chunk_num = $chunk_num\n";
	    if($chunk_num > 1) {
		&merge();
	    }
	}
	close(INFILE);
	$tempfilename = $CHR[$cnt] . "_temp.0";
	close(FINALOUT);
	`cat $tempfilename >> $outfile`;
	open(FINALOUT, ">>$outfile");
	unlink($tempfilename);
	$tempfilename = $CHR[$cnt] . "_temp.1";
	unlink($tempfilename);
	$tempfilename = $CHR[$cnt] . "_temp.2";
	unlink($tempfilename);
	$cnt++;
	$chunk++;
	next;
    }

    # START NORMAL CASE (SO NOT DEALING WITH A MONSTER CHROMOSOME)

    $cnt++;
    while($running_count+$chr_counts{$CHR[$cnt]} < $max_count_at_once && $cnt < @CHR) {
	$running_count = $running_count + $chr_counts{$CHR[$cnt]};
	$chrs_current{$CHR[$cnt]} = 1;
	print STDERR " $CHR[$cnt] ";
	$cnt++;
    }
    print STDERR "\n";
#    print "-----------\n";
    $INFILE = $infile . "_sorting_tempfile." . $chunk;
    open(INFILE, $INFILE);
    while($line = <INFILE>) {
	chomp($line);
	@a = split(/\t/,$line);
	$chr = $a[1];
	$a[2] =~ /^(\d+)-/;
	$start = $1;
	if($a[0] =~ /a/ && $separate eq "false") {
	    $a[0] =~ /(\d+)/;
	    $seqnum1 = $1;
	    $line2 = <INFILE>;
	    chomp($line2);
	    @b = split(/\t/,$line2);
	    $b[0] =~ /(\d+)/;
	    $seqnum2 = $1;
	    if($seqnum1 == $seqnum2 && $b[0] =~ /b/) {
		if($a[3] eq "+") {
		    $b[2] =~ /-(\d+)$/;
		    $end = $1;
		} else {
		    $b[2] =~ /^(\d+)-/;
		    $start = $1;
		    $a[2] =~ /-(\d+)$/;
		    $end = $1;
		}
		$hash{$chr}{$line . "\n" . $line2}[0] = $start;
		$hash{$chr}{$line . "\n" . $line2}[1] = $end;
	    } else {
		$a[2] =~ /-(\d+)$/;
		$end = $1;
		# reset the file handle so the last line read will be read again
		$len = -1 * (1 + length($line2));
		seek(INFILE, $len, 1);
		$hash{$chr}{$line}[0] = $start;
		$hash{$chr}{$line}[1] = $end;
	    }
	} else {
	    $a[2] =~ /-(\d+)$/;
	    $end = $1;
	    $hash{$chr}{$line}[0] = $start;
	    $hash{$chr}{$line}[1] = $end;
	}
    }
    close(INFILE);
    foreach $chr (sort cmpChrs keys %hash) {
	foreach $line (sort {$hash{$chr}{$a}[0]<=>$hash{$chr}{$b}[0] || ($hash{$chr}{$a}[0]==$hash{$chr}{$b}[0] && $hash{$chr}{$a}[1]<=>$hash{$chr}{$b}[1])} keys %{$hash{$chr}}) {
	    chomp($line);
	    if($line =~ /\S/) {
		print FINALOUT $line;
		print FINALOUT "\n";
	    }
	}
	close(FINALOUT);
	open(FINALOUT, ">>$outfile"); # did this just to flush the buffer
    }
    $chunk++;
}
close(FINALOUT);

for($chunk=0;$chunk<$numchunks;$chunk++) {
    $tempfile =  $infile . "_sorting_tempfile." . $chunk;
    unlink($tempfile);
}
$timeend = time();
$timelapse = $timeend - $timestart;
if($timelapse < 60) {
    print STDERR "\nIt took $timelapse seconds to sort '$infile'.\n\n";
}
else {
    $sec = $timelapse % 60;
    $min = int($timelapse / 60);
    if($min > 1 && $sec > 1) {
	print STDERR "\nIt took $min minutes, $sec seconds to sort '$infile'.\n\n";
    }
    if($min == 1 && $sec > 1) {
	print STDERR "\nIt took $min minute, $sec seconds to sort '$infile'.\n\n";
    }
    if($min > 1 && $sec == 1) {
	print STDERR "\nIt took $min minutes, $sec second to sort '$infile'.\n\n";
    }
    if($min == 1 && $sec == 1) {
	print STDERR "\nIt took $min minute, $sec second to sort '$infile'.\n\n";
    }
}

sub cmpChrs () {
    $a2_c = lc($b);
    $b2_c = lc($a);
    if($a2_c =~ /chr(\d+)$/ && !($b2_c =~ /chr(\d+)$/)) {
	return 1;
    }
    if($b2_c =~ /chr(\d+)$/ && !($a2_c =~ /chr(\d+)$/)) {
	return -1;
    }
    if($a2_c =~ /chr([a-z])$/ && !($b2_c =~ /chr(\d+)$/) && !($b2_c =~ /chr[a-z]+$/)) {
	return 1;
    }
    if($b2_c =~ /chr([a-z])$/ && !($a2_c =~ /chr(\d+)$/) && !($a2_c =~ /chr[a-z]+$/)) {
	return -1;
    }
    if($a2_c =~ /chr[^xy\d]/ && (($b2_c =~ /chrx/) || ($b2_c =~ /chry/))) {
	return -1;
    }
    if($b2_c =~ /chr[^xy\d]/ && (($a2_c =~ /chrx/) || ($a2_c =~ /chry/))) {
	return 1;
    }
    
    if($a2_c =~ /chr(\d+)/) {
	$numa = $1;
	if($b2_c =~ /chr(\d+)/) {
	    $numb = $1;
	    if($numa <= $numb) {return 1;} else {return -1;}
	} else {
	    return 1;
	}
    }
    if($a2_c =~ /chr([a-z]+)/) {
	$letter_a = $1;
	if($b2_c =~ /chr([a-z]+)/) {
	    $letter_b = $1;
	    if($letter_a le $letter_b) {return 1;} else {return -1;}
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

    return 1;
}

sub merge() {
    $tempfilename1 = $CHR[$cnt] . "_temp.0";
    $tempfilename2 = $CHR[$cnt] . "_temp.1";
    $tempfilename3 = $CHR[$cnt] . "_temp.2";
    open(TEMPMERGEDOUT, ">$tempfilename3");
    open(TEMPIN1, $tempfilename1);
    open(TEMPIN2, $tempfilename2);
    $mergeFLAG = 0;
    getNext1();
    getNext2();
    while($mergeFLAG < 2) {
	chomp($out1);
	chomp($out2);
	if($start1 < $start2) {
	    if($out1 =~ /\S/) {
		print TEMPMERGEDOUT "$out1\n";
	    }
	    getNext1();
	} elsif($start1 == $start2) {
	    if($end1 <= $end2) {
		if($out1 =~ /\S/) {
		    print TEMPMERGEDOUT "$out1\n";
		}
		getNext1();
	    } else {
		if($out2 =~ /\S/) {
		    print TEMPMERGEDOUT "$out2\n";
		}
		getNext2();
	    }
	} else {
	    if($out2 =~ /\S/) {
		print TEMPMERGEDOUT "$out2\n";
	    }
	    getNext2();
	}
    }
    close(TEMPMERGEDOUT);
    `mv $tempfilename3 $tempfilename1`;
    unlink($tempfilename2);
}

sub getNext1 () {
    $line1 = <TEMPIN1>;
    chomp($line1);
    if($line1 eq '') {
	$mergeFLAG++;
	$start1 = 1000000000000;  # effectively infinity, no chromosome should be this large;
	return "";
    }
    @a = split(/\t/,$line1);
    $a[2] =~ /^(\d+)-/;
    $start1 = $1;
    if($a[0] =~ /a/ && $separate eq "false") {
	$a[0] =~ /(\d+)/;
	$seqnum1 = $1;
	$line2 = <TEMPIN1>;
	chomp($line2);
	@b = split(/\t/,$line2);
	$b[0] =~ /(\d+)/;
	$seqnum2 = $1;
	if($seqnum1 == $seqnum2 && $b[0] =~ /b/) {
	    if($a[3] eq "+") {
		$b[2] =~ /-(\d+)$/;
		$end1 = $1;
	    } else {
		$b[2] =~ /^(\d+)-/;
		$start1 = $1;
		$a[2] =~ /-(\d+)$/;
		$end1 = $1;
	    }
	    $out1 = $line1 . "\n" . $line2;
	} else {
	    $a[2] =~ /-(\d+)$/;
	    $end1 = $1;
	    # reset the file handle so the last line read will be read again
	    $len = -1 * (1 + length($line2));
	    seek(TEMPIN1, $len, 1);
	    $out1 = $line1;
	}
    } else {
	$a[2] =~ /-(\d+)$/;
	$end1 = $1;
	$out1 = $line1;
    }
}

sub getNext2 () {
    $line1 = <TEMPIN2>;
    chomp($line1);
    if($line1 eq '') {
	$mergeFLAG++;
	$start2 = 1000000000000;  # effectively infinity, no chromosome should be this large;
	return "";
    }
    @a = split(/\t/,$line1);
    $a[2] =~ /^(\d+)-/;
    $start2 = $1;
    if($a[0] =~ /a/ && $separate eq "false") {
	$a[0] =~ /(\d+)/;
	$seqnum1 = $1;
	$line2 = <TEMPIN2>;
	chomp($line2);
	@b = split(/\t/,$line2);
	$b[0] =~ /(\d+)/;
	$seqnum2 = $1;
	if($seqnum1 == $seqnum2 && $b[0] =~ /b/) {
	    if($a[3] eq "+") {
		$b[2] =~ /-(\d+)$/;
		$end2 = $1;
	    } else {
		$b[2] =~ /^(\d+)-/;
		$start2 = $1;
		$a[2] =~ /-(\d+)$/;
		$end2 = $1;
	    }
	    $out2 = $line1 . "\n" . $line2;
	} else {
	    $a[2] =~ /-(\d+)$/;
	    $end2 = $1;
	    # reset the file handle so the last line read will be read again
	    $len = -1 * (1 + length($line2));
	    seek(TEMPIN2, $len, 1);
	    $out2 = $line1;
	}
    } else {
	$a[2] =~ /-(\d+)$/;
	$end2 = $1;
	$out2 = $line1;
    }
}
