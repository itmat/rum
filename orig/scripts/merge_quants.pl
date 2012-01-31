#!/usr/bin/perl

# Written by Gregory R Grant
# University of Pennsylvania, 2010

if(@ARGV<3) {
    die "
Usage: merge_quants.pl <dir> <numchunks> <outfile> [options]

option:

    -strand s : ps, ms, pa, or ma (p: plus, m: minus, s: sense, a: antisense)

    -chunk_ids_file f : If a file mapping chunk N to N.M.  This is used
                        specifically for the RUM pipeline when chunks were
                        restarted and names changed. 

    -countsonly :  Output only a simple file with feature names and counts.

    -alt :  need this if using -altquant when running RUM

This script will look in <dir> for files named quant.1, quant.2, etc..
up to quant.numchunks.  Unless -strand S is set in which case it looks
for quant.S.1, quant.S.2, etc...

";
}

$output_dir = $ARGV[0]; 
$numchunks = $ARGV[1];
$outfile = $ARGV[2];
$strandspecific = "false";
$strand = "";
$chunk_ids_file = "";
$countsonly = "false";
$alt = "false";
for($i=3; $i<@ARGV; $i++) {
    $optionrecognized = 0;
    if($ARGV[$i] eq "-strand") {
	$strand = $ARGV[$i+1];
	$strandspecific="true";
	$i++;
	if(!($strand eq 'pa' || $strand eq 'ma' || $strand eq 'ps' || $strand eq 'ms')) {
	    die "\nError: in file merge_quants.pl: -strand must equal either ps, ms, pa or ma, not '$strand'\n\n";
	}
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-chunk_ids_file") {
	$chunk_ids_file = $ARGV[$i+1];
	$i++;
	if(-e $chunk_ids_file) {
	    open(INFILE, $chunk_ids_file) or die "Error: cannot open '$chunk_ids_file' for reading.\n\n";
	    while($line = <INFILE>) {
		chomp($line);
		@a = split(/\t/,$line);
		$chunk_ids_mapping{$a[0]} = $a[1];
	    }
	    close(INFILE);
	}
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-countsonly") {
	$countsonly = "true";
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-alt") {
	$alt = "true";
	$optionrecognized = 1;
    }
    if($optionrecognized == 0) {
	die "\nError: option '$ARGV[$i]' not recognized.\n\n";
    }
}

$num_reads = 0;
$first = 1;
for($i=1; $i<=$numchunks; $i++) {
    if($strandspecific eq "true") {
	if($alt eq "false") {
	    $filename = "quant.$strand.$i";
	} else {
	    $filename = "quant.$strand.altquant.$i";
	}
    } else {
	if($alt eq "false") {
	    $filename = "quant.$i";
	} else {
	    $filename = "quant.altquant.$i";
	}
    }
    if($chunk_ids_file =~ /\S/ && $chunk_ids_mapping{$i} =~ /\S/) {
	$filename = $filename . "." . $chunk_ids_mapping{$i};
    }
    open(INFILE, "$output_dir/$filename");
    $line = <INFILE>;
    $line =~ /num_reads = (\d+)/;
    $num_reads = $num_reads + $1;
    $cnt=0;
    while($line = <INFILE>) {
	chomp($line);
	@a = split(/\t/,$line);
	$counts[$cnt]{Ucnt} = $counts[$cnt]{Ucnt} + $a[2];
	$counts[$cnt]{NUcnt} = $counts[$cnt]{NUcnt} + $a[3];
	if($first == 1) {
	    $counts[$cnt]{type} = $a[0];
	    $counts[$cnt]{coords} = $a[1];
	    $counts[$cnt]{len} = $a[4];
	    $counts[$cnt]{strand} = $a[5];
	    $counts[$cnt]{id} = $a[6];
	}
	$cnt++;
    }
    $first = 0;
}
$num_reads_hold = $num_reads;
$num_reads = $num_reads / 1000000;
open(OUTFILE, ">$outfile");
print OUTFILE "number of reads used for normalization: $num_reads_hold\n";
for($i=0; $i<$cnt; $i++) {
    $NL = $counts[$i]{len} / 1000;
    if($countsonly eq "false") {
	$ucnt_normalized = int( $counts[$i]{Ucnt} / $NL / $num_reads * 10000 ) / 10000;
	$totalcnt_normalized = int( ($counts[$i]{NUcnt}+$counts[$i]{Ucnt}) / $NL / $num_reads * 10000 ) / 10000;
    } else {
	$ucnt_normalized = $counts[$i]{Ucnt};
	$totalcnt_normalized = $counts[$i]{NUcnt}+$counts[$i]{Ucnt};
    }
    if($counts[$i]{type} eq 'transcript') {
	print OUTFILE "--------------------------------------------------------------------\n";
	print OUTFILE "$counts[$i]{id}\t$counts[$i]{strand}\n";
	print OUTFILE "      Type\tLocation           \tmin\tmax\tUcount\tNUcount\tLength\n";
	print OUTFILE "transcript\t$counts[$i]{coords}\t$ucnt_normalized\t$totalcnt_normalized\t$counts[$i]{Ucnt}\t$counts[$i]{NUcnt}\t$counts[$i]{len}\n";
	$exoncnt = 1;
	$introncnt = 1;
    } elsif($counts[$i]{type} eq 'exon') {
	print OUTFILE "  exon $exoncnt\t$counts[$i]{coords}\t$ucnt_normalized\t$totalcnt_normalized\t$counts[$i]{Ucnt}\t$counts[$i]{NUcnt}\t$counts[$i]{len}\n";
	$exoncnt++;
    } elsif($counts[$i]{type} eq 'intron') {
	print OUTFILE "intron $introncnt\t$counts[$i]{coords}\t$ucnt_normalized\t$totalcnt_normalized\t$counts[$i]{Ucnt}\t$counts[$i]{NUcnt}\t$counts[$i]{len}\n";
	$introncnt++;
    }
}
close(OUTFILE);
