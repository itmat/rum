#!/usr/bin/perl

$|=1;

use FindBin qw($Bin);
use lib "$Bin/../../lib";

use RUM::Common qw(roman Roman isroman arabic);

$timestart = time();
if(@ARGV < 2) {
    die "
Usage: sort_RUM_by_location.pl <rum file> <sorted file> [options]

Where: <rum file> is the RUM_Unique or RUM_NU file output from
       the RUM pipeline.

       <sorted file> is the name of the sorted output file

Options: -separate : Do not (necessarily) keep forward and reverse
                     together.  By default they are kept together.

         -maxchunksize n : is the max number of reads that the program tries to
         read into memory all at once.  Default = 10,000,000

         -ram n    : the number of GB of RAM if less than 8, otherwise
                     will assume you have 8, give or take, and pray...
                     If you have some millions of reads and not at
                     least 4Gb then this is probably not going to work.

";
}


$separate = "false";
$ram = 6;
$infile = $ARGV[0];
$outfile = $ARGV[1];
$running_indicator_file = $ARGV[1];
$running_indicator_file =~ s![^/]+$!!;
$running_indicator_file = $running_indicator_file . ".running";
open(OUTFILE, ">$running_indicator_file") or die "ERROR: in script sort_RUM_by_location.pl: cannot open file '$running_indicator_file' for writing.\n\n";
print OUTFILE "0";
close(OUTFILE);

$maxchunksize = 9000000;
$maxchunksize_specified = "false";
for($i=2; $i<@ARGV; $i++) {
    $optionrecognized = 0;
    if($ARGV[$i] eq "-separate") {
	$separate = "true";
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-ram") {
	$ram = $ARGV[$i+1];
	if(!($ram =~ /^\d+$/)) {
	    die "\nERROR: in script sort_RUM_by_location.pl: -ram must be an integer greater than zero, you gave '$ram'.\n\n";
	} elsif($ram==0) {
	    die "\nERROR: in script sort_RUM_by_location.pl: -ram must be an integer greater than zero, you gave '$ram'.\n\n";
	}
	$i++;
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-maxchunksize") {
	$maxchunksize = $ARGV[$i+1];
	if(!($maxchunksize =~ /^\d+$/)) {
	    die "\nERROR: in script sort_RUM_by_location.pl: -maxchunksize must be an integer greater than zero, you gave '$maxchunksize'.\n\n";
	} elsif($maxchunksize==0) {
	    die "\nERROR: in script sort_RUM_by_location.pl: -maxchunksize must be an integer greater than zero, you gave '$maxchunksize'.\n\n";
	}
	$i++;
	$optionrecognized = 1;
	$maxchunksize_specified = "true";
    }
    if($ARGV[$i] eq "-name") {
	$name = $ARGV[$i+1];
	$i++;
	$optionrecognized = 1;
    }
    if($optionrecognized == 0) {
	die "\nERROR: in script sort_RUM_by_location.pl: option '$ARGV[$i]' not recognized\n";
    }
}
if ($maxchunksize < 500000) {
    die "ERROR: in script sort_RUM_by_location.pl: <max chunk size> must at least 500,000.\n\n";
}

if($maxchunksize_specified eq "false") {
    if($ram >= 7) {
	$max_count_at_once = 10000000;
    } elsif($ram >=6) {
	$max_count_at_once = 8500000;
    } elsif($ram >=5) {
	$max_count_at_once = 7500000;
    } elsif($ram >=4) {
	$max_count_at_once = 6000000;
    } elsif($ram >=3) {
	$max_count_at_once = 4500000;
    } elsif($ram >=2) {
	$max_count_at_once = 3000000;
    } else {
	$max_count_at_once = 1500000;
    }
} else {
    $max_count_at_once = $maxchunksize;
}

&doEverything();

$size_input = -s $infile;
$size_output = -s $outfile;

$clean = "false";
for($i=0; $i<2; $i++) {
    if($size_input != $size_output) {
	print STDERR "Warning: from script sort_RUM_by_location.pl on \"$infile\": sorting failed, trying again.\n";
	&doEverything();
	$size_output = -s $outfile;
    } else {
	$i = 2;
	$clean = "true";
	print "\n$infile reads per chromosome:\n\nchr_name\tnum_reads\n";
	foreach $chr (sort {cmpChrs($a,$b)} keys %chr_counts) {
	    print "$chr\t$chr_counts{$chr}\n";
	}
    }
}

if($clean eq "false") {
    print STDERR "ERROR: from script sort_RUM_by_location.pl on \"$infile\": the size of the unsorted input ($size_input) and sorted output\nfiles ($size_output) are not equal.  I tried three times and it failed every\ntime.  Must be something strange about the input file...\n\n";
}

sub doEverything () {

    open(INFILE, $infile);
    open(FINALOUT, ">$outfile");

    undef %chr_counts;
    undef @CHR;
    undef @CHUNK;
    undef %hash;

    $num_prev = "0";
    $type_prev = "";
    while($line = <INFILE>) {
	chomp($line);
	@a = split(/\t/,$line);
	$line =~ /^seq.(\d+)([^\d])/;
	$num = $1;
	$type = $2;
	if($num eq $num_prev && $type_prev eq "a" && $type eq "b") {
	    $type_prev = $type;
	    next;
	}
	if($a[1] =~ /\S/) {
	    $chr_counts{$a[1]}++;
	}
	$num_prev = $num;
	$type_prev = $type;
    }
    close(INFILE);
    
    $cnt=0;
    foreach $chr (sort {cmpChrs($a,$b)} keys %chr_counts) {
	$CHR[$cnt] = $chr;
	$cnt++;
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
#foreach $chr (sort {cmpChrs($a,$b)} keys %CHUNK) {
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
    
    while($cnt < @CHR) {
	undef %chrs_current;
	undef %hash;
	$running_count = $chr_counts{$CHR[$cnt]};
	$chrs_current{$CHR[$cnt]} = 1;
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
	    $cnt++;
	}
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
	foreach $chr (sort {cmpChrs($a,$b)} keys %hash) {
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
#$timeend = time();
#$timelapse = $timeend - $timestart;
#if($timelapse < 60) {
#    if($timelapse == 1) {
#	print "\nIt took one second to sort '$infile'.\n\n";
#    } else {
#	print "\nIt took $timelapse seconds to sort '$infile'.\n\n";
#    }
#}
#else {
#    $sec = $timelapse % 60;
#    $min = int($timelapse / 60);
#    if($min > 1 && $sec > 1) {
#	print "\nIt took $min minutes, $sec seconds to sort '$infile'.\n\n";
#    }
#    if($min == 1 && $sec > 1) {
#	print "\nIt took $min minute, $sec seconds to sort '$infile'.\n\n";
#    }
#    if($min > 1 && $sec == 1) {
#	print "\nIt took $min minutes, $sec second to sort '$infile'.\n\n";
#    }
#    if($min == 1 && $sec == 1) {
#	print "\nIt took $min minute, $sec second to sort '$infile'.\n\n";
#    }
#}

    unlink($running_indicator_file);
}

sub cmpChrs () {
    $a2_c = lc($b);
    $b2_c = lc($a);
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

