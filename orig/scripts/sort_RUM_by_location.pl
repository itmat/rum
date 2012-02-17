#!/usr/bin/perl

$|=1;

use FindBin qw($Bin);
use lib "$Bin/../../lib";

use RUM::Common qw(roman Roman isroman arabic);
use RUM::ChrCmp qw(cmpChrs);
use RUM::FileIterator qw(file_iterator pop_it peek_it);

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

         -allowsmallchunks : Allow -maxchunksize to be less than 500,000.
                             This may be useful for testing purposes.
";
}

my $allowsmallchunks = 0;

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
    if ($ARGV[$i] eq "-allowsmallchunks") {
        $allowsmallchunks = 1;
        $optionrecognized = 1;
    }
    if($optionrecognized == 0) {
	die "\nERROR: in script sort_RUM_by_location.pl: option '$ARGV[$i]' not recognized\n";
    }
}
# We have a test that exercises the ability to merge chunks together,
# so allow max chunk sizes smaller than 500000 if that flag is set.
if ($maxchunksize < 500000 && !$allowsmallchunks) {
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

sub get_chromosome_counts {
    use strict;
    my ($infile) = @_;
    open my $in, "<", $infile;

    my %counts;

    my $num_prev = "0";
    my $type_prev = "";
    while(my $line = <$in>) {
	chomp($line);
	my @a = split(/\t/,$line);
	$line =~ /^seq.(\d+)([^\d])/;
	my $num = $1;
	my $type = $2;
	if($num eq $num_prev && $type_prev eq "a" && $type eq "b") {
	    $type_prev = $type;
	    next;
	}
	if($a[1] =~ /\S/) {
	    $counts{$a[1]}++;
	}
	$num_prev = $num;
	$type_prev = $type;
    }
    return %counts;
}

sub doEverything () {

    open(FINALOUT, ">$outfile");

    my %chr_counts = get_chromosome_counts($infile);
    undef @CHR;
    undef @CHUNK;
    undef %hash;

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
	    open my $in, "<", $INFILE;
	    $FLAG = 0;
	    $chunk_num = 0;
	    while($FLAG == 0) {
                
		$chunk_num++;
		$number_so_far = 0;
		undef %hash;
		$chunkFLAG = 0;
		# read in one chunk:
		while($chunkFLAG == 0) {
		    $line = <$in>;
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
			$line2 = <$in>;
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
			    seek($in, $len, 1);
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
		foreach $line (sort {
                    $hash{$a}[0]<=>$hash{$b}[0] || 
                    $hash{$a}[1]<=>$hash{$b}[1]
                } keys %hash) {
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
                    $tempfilename1 = $CHR[$cnt] . "_temp.0";
                    $tempfilename2 = $CHR[$cnt] . "_temp.1";
                    $tempfilename3 = $CHR[$cnt] . "_temp.2";
                    my $wc = `wc -l $tempfilename1 $tempfilename2`;
		    &merge($tempfilename1, $tempfilename2, $tempfilename3);
                    #warn "Merged\n$wc\ninto\n".`wc -l $tempfilename1`;
		}
	    }
	    close($in);
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
	open(my $foo_in, $INFILE);
        populate_hash($foo_in, \%hash, $separate);
	close($foo_in);
	foreach $chr (sort {cmpChrs($a,$b)} keys %hash) {
	    foreach $line (sort {
                $hash{$chr}{$a}[0]<=>$hash{$chr}{$b}[0] || 
                $hash{$chr}{$a}[1]<=>$hash{$chr}{$b}[1] ||
                $hash{$chr}{$a}[2]<=>$hash{$chr}{$b}[2]
            } keys %{$hash{$chr}}) { 
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

sub populate_hash {
    my ($in, $hash, $separate) = @_;
    use strict;
    use warnings;    
    my $it = file_iterator($in, separate => 0);

    while(my $row = pop_it($it)) {
        my $chr = $row->{chr};
        my $entry = $row->{entry};
        $hash->{$chr}{$entry}[0] = $row->{start};
        $hash->{$chr}{$entry}[1] = $row->{end};
        $hash->{$chr}{$entry}[2] = $row->{seqnum};
    }
}

sub merge {

    use strict;

    my ($in1, $in2, $out) = @_;

    open my $temp_merged_out, ">", $out;
    my @iters;
    for my $in_filename ($in1, $in2) {
        open my $in, "<", $in_filename;
        my $iter = file_iterator($in, separate => 0);
        push @iters, $iter if peek_it($iter);
    }

    while (defined(my $rec1 = peek_it($iters[0])) &&
           defined(my $rec2 = peek_it($iters[1]))) {

        # Find the iterator whose next record is smaller (has smaller
        # start or smaller end). Pop that iterator and print the
        # record.
        my $cmp = $rec1->{start} <=> $rec2->{start} || 
                    $rec1->{end} <=> $rec2->{end}   ||
                 $rec1->{seqnum} <=> $rec2->{seqnum};

        my $iter = $cmp < 0 ? $iters[0] : $iters[1];
        print $temp_merged_out pop_it($iter)->{entry}, "\n";
    }
    
    # When we get here we must have exhausted one of the iterators, so
    # drain the other one.
    for my $iter (@iters) {
        while (defined(my $rec = pop_it($iter))) {
            print $temp_merged_out $rec->{entry}, "\n";
        }
    }

    close($temp_merged_out);

    `mv $out $in1`;
    unlink($in2);
}
