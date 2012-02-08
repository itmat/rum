#!/usr/bin/perl

# Written by Gregory R Grant
# University of Pennsylvania, 2010

$|=1;

use FindBin qw($Bin);
use lib "$Bin/../../lib";

use RUM::Common qw(roman Roman isroman arabic);

use strict;

if(@ARGV < 4) {
    die "
Usage: rum2quantifications.pl <annot file> <RUM_Unique> <RUM_NU> <outfile> [options]

Where:

    <annot file> is the transcript models file for the RUM pipeline

    <RUM_Unique> is the sorted RUM Unique file

    <RUM_NU> is the sorted RUM NU file

    <outfile> the file to write the results to

Options:

    -sepout filename : Make separate files for the min and max experssion values.
                       In this case will write the min values to <outfile> and the   
                       max values to the file specified by 'filename'.
                       There are two extra columns in each file if done this way,
                       one giving the raw count and one giving the count normalized
                       only by the feature length.

    -posonly  :  Output results only for transcripts that have non-zero intensity.
                 Note: if using -sepout, this will output results to both files for
                 a transcript if either one of the unique or non-unique counts is zero.

    -countsonly :  Output only a simple file with feature names and counts.

    -strand s : s=p to use just + strand reads, s=m to use just - strand.

    -info f   : f is a file that maps gene id's to info (i.e. annotation or other gene ids).
                f must be tab delmited with the first column of known ids and second
                column of annotation.

    -anti     : Use in conjunction with -strand to record anti-sense transcripts instead
                of sense. 

";
}

my $annotfile = $ARGV[0];
my $U_readsfile = $ARGV[1];
my $NU_readsfile = $ARGV[2];
my $outfile1 = $ARGV[3];
my $outfile2;

my %TRANSCRIPT;
my %EXON_temp;
my %INTRON_temp;
my %cnt;
my @A;
my @B;
my %tcnt;
my %ecnt;
my %icnt;
my @READS;

my $sepout = "false";
my $posonly = "false";
my $countsonly = "false";
my $strandspecific="false";
my $strand = "";
my $anti = "false";
my $infofile;
my $infofile_given = "false";
for(my $i=4; $i<@ARGV; $i++) {
    my $optionrecognized = 0;
    if($ARGV[$i] eq "-sepout") {
	$sepout = "true";
	$outfile2 = $ARGV[$i+1];
	$i++;
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-info") {
	$infofile_given = "true";
        $i++;
        $infofile = $ARGV[$i];
        if(!(-e $infofile)) {
            die "ERROR: in script rum2quantifications.pl: info file '$infofile' does not seem to exist.\n\n";
        }
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-strand") {
	$strand = $ARGV[$i+1];
	$strandspecific="true";
	$i++;
	if(!($strand eq 'p' || $strand eq 'm')) {
	    die "\nERROR: in script rum2quantifications.pl: -strand must equal either 'p' or 'm', not '$strand'\n\n";
	}
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-posonly") {
	$posonly = "true";
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-anti") {
	$anti = "true";
	$optionrecognized = 1;
    }
    if($ARGV[$i] eq "-countsonly") {
	$countsonly = "true";
	$optionrecognized = 1;
    }
    if($optionrecognized == 0) {
	die "\nERROR: in script rum2quantifications.pl: option '$ARGV[$i]' not recognized\n";
    }
}

# read in the info file, if given

my %INFO;
if($infofile_given eq "true") {
    open(INFILE, $infofile) or die "ERROR: in script rum2quantifications.pl: Cannot open the file '$infofile' for reading\n";
    while(my $line = <INFILE>) {
	chomp($line);
	my @a = split(/\t/,$line);
	$INFO{$a[0]} = $a[1];
    }
    close(INFILE);
}

# read in the transcript models

open(INFILE, $annotfile) or die "ERROR: in script rum2quantifications.pl: cannot open '$annotfile' for reading.\n\n";
while(my $line = <INFILE>) {
    chomp($line);
    my @a = split(/\t/,$line);

    my $STRAND = $a[3];
    if($strandspecific eq 'true') {
	if($strand =~ /^p/ && $a[1] eq '-') {
	    next;
	}
	if($strand =~ /^m/ && $a[1] eq '+') {
	    next;
	}
    }

    $a[5] =~ s/\s*,\s*$//;
    $a[6] =~ s/\s*,\s*$//;
    my $chr = $a[0];
    $tcnt{$chr}=$tcnt{$chr}+0;
    $TRANSCRIPT{$chr}[$tcnt{$chr}]{strand} = $a[1];
    $TRANSCRIPT{$chr}[$tcnt{$chr}]{num} = $a[4];
    $TRANSCRIPT{$chr}[$tcnt{$chr}]{start} = $a[2]+1;  # add one to convert to one-based coords
    $TRANSCRIPT{$chr}[$tcnt{$chr}]{end} = $a[3];
    my @s = split(/,/,$a[5]);
    my @e = split(/,/,$a[6]);
    my @c;
    my $transcript_length=0;
    for(my $i=0; $i<@s; $i++) {
	$TRANSCRIPT{$chr}[$tcnt{$chr}]{coords}[2*$i]=$s[$i]+1;  # add one to convert to one-based coords
	$TRANSCRIPT{$chr}[$tcnt{$chr}]{coords}[2*$i+1]=$e[$i];
	my $S = $s[$i]+1;
	my $E = $chr . ":" . $S . "-" . $e[$i];
	$transcript_length = $transcript_length + $e[$i] - $S + 1;
	$EXON_temp{$chr}{$E}{start} = $S;
	$EXON_temp{$chr}{$E}{end} = $e[$i];
	if($i < @s-1) {
	    my $s2 = $e[$i]+1;
	    my $e2 = $s[$i+1];
	    my $E = $chr . ":" . $s2 . "-" . $e2;
	    $INTRON_temp{$chr}{$E}{start} = $s2;
	    $INTRON_temp{$chr}{$E}{end} = $e2;
	}
    }
    $TRANSCRIPT{$chr}[$tcnt{$chr}]{length} = $transcript_length;
    $TRANSCRIPT{$chr}[$tcnt{$chr}]{id} = $a[7];
    $tcnt{$chr}++;
}
close(INFILE);

my %EXON;
foreach my $chr (sort {cmpChrs($a,$b)} keys %EXON_temp) {
    $ecnt{$chr} = 0;
    foreach my $exon (sort {$EXON_temp{$chr}{$a}{start} <=> $EXON_temp{$chr}{$b}{start}} keys %{$EXON_temp{$chr}}) {
	$EXON{$chr}[$ecnt{$chr}]{start} = $EXON_temp{$chr}{$exon}{start};
	$EXON{$chr}[$ecnt{$chr}]{end} = $EXON_temp{$chr}{$exon}{end};
	$EXON{$chr}[$ecnt{$chr}]{exon} = $exon;
	$ecnt{$chr}++;
    }
}
my %INTRON;
foreach my $chr (sort {cmpChrs($a,$b)} keys %INTRON_temp) {
    $icnt{$chr} = 0;
    foreach my $intron (sort {$INTRON_temp{$chr}{$a}{start} <=> $INTRON_temp{$chr}{$b}{start}} keys %{$INTRON_temp{$chr}}) {
	$INTRON{$chr}[$icnt{$chr}]{start} = $INTRON_temp{$chr}{$intron}{start};
	$INTRON{$chr}[$icnt{$chr}]{end} = $INTRON_temp{$chr}{$intron}{end};
	$INTRON{$chr}[$icnt{$chr}]{intron} = $intron;
	$icnt{$chr}++;
    }
}

&readfile($U_readsfile, "Ucount");
&readfile($NU_readsfile, "NUcount");

my %EXONhash;
foreach my $chr (sort {cmpChrs($a,$b)} keys %EXON) {
    for(my $i=0; $i<$ecnt{$chr}; $i++) {
	my $x1 = $EXON{$chr}[$i]{Ucount}+0;
	my $x2 = $EXON{$chr}[$i]{NUcount}+0;
	my $y = $EXON{$chr}[$i]{id};
	my $s = $EXON{$chr}[$i]{start};
	my $e = $EXON{$chr}[$i]{end};
	my $exon = $chr . ":" . $EXON{$chr}[$i]{start} . "-" . $EXON{$chr}[$i]{end};
	$EXONhash{$exon}{u} = $x1;
	$EXONhash{$exon}{nu} = $x2;
    }
}
my %INTRONhash;
foreach my $chr (sort {cmpChrs($a,$b)} keys %INTRON) {
    for(my $i=0; $i<$icnt{$chr}; $i++) {
	my $x1 = $INTRON{$chr}[$i]{Ucount}+0;
	my $x2 = $INTRON{$chr}[$i]{NUcount}+0;
	my $y = $INTRON{$chr}[$i]{id};
	my $s = $INTRON{$chr}[$i]{start};
	my $e = $INTRON{$chr}[$i]{end};
	my $intron = $chr . ":" . $INTRON{$chr}[$i]{start} . "-" . $INTRON{$chr}[$i]{end};
	$INTRONhash{$intron}{u} = $x1;
	$INTRONhash{$intron}{nu} = $x2;
    }
}

open(OUTFILE1, ">$outfile1") or die "ERROR: in script rum2quantifications.pl: cannot open file '$outfile1' for writing.\n\n";
if($sepout eq "true") {
    open(OUTFILE2, ">$outfile2") or die "ERROR: in script rum2quantifications.pl: cannot open file '$outfile2' for writing.\n\n";
}

my $num_reads = 0;
for(my $i=0; $i<@READS; $i++) {
    if($READS[$i]+0 == 1) {
	$num_reads++;
    }
}

my $nr = $num_reads / 1000000;
if($countsonly eq "true") {
    print OUTFILE1 "num_reads = $num_reads\n";
}
foreach my $chr (sort {cmpChrs($a,$b)} keys %TRANSCRIPT) {
    for(my $i=0; $i<$tcnt{$chr}; $i++) {
	my $x1 = $TRANSCRIPT{$chr}[$i]{Ucount}+0;
	my $x2 = $TRANSCRIPT{$chr}[$i]{NUcount}+0;
	my $y = $TRANSCRIPT{$chr}[$i]{id};
	my $s = $TRANSCRIPT{$chr}[$i]{start};
	my $e = $TRANSCRIPT{$chr}[$i]{end};
	my $st = $TRANSCRIPT{$chr}[$i]{strand};
	my $z = $x1 + $x2;
	my $nl = $TRANSCRIPT{$chr}[$i]{length} / 1000;
	my $n1;
	my $n2;
	if($nl == 0 || $nr == 0) {
	    $n1=0;
	    $n2=0;
	} else {
	    $n1 = int($x1 / $nl / $nr * 10000) / 10000;
	    $n2 = int($z / $nl / $nr * 10000) / 10000;
	}
	if($posonly eq "false" || ($posonly eq "true" && $z > 0)) {
	    if($countsonly eq "false") {
		print OUTFILE1 "--------------------------------------------------------------------\n";
		if($sepout eq "true") {
		    print OUTFILE2 "--------------------------------------------------------------------\n";
		}
	    }
	    my $tlen = $TRANSCRIPT{$chr}[$i]{length};
	    if($countsonly eq "false") {
		if($sepout eq "true") {
		    print OUTFILE1 "$y\t$st\n";
		    print OUTFILE1 "      Type\tLocation           \tCount\tAve_Cnt\tRPKM\tLength\n";
		    print OUTFILE2 "$y\t$st\n";
		    print OUTFILE2 "      Type\tLocation           \tCount\tAve_Cnt\tRPKM\tLength\n";
		    my $x3;
		    if($nl == 0) {
			$x3=0;
		    } else {
			$x3 = int($x1 / $nl * 10000) / 10000;
		    }
		    print OUTFILE1 "transcript\t$chr:$s-$e\t$x1\t$x3\t$n1\t$tlen\t$y\n";

		    if($nl == 0) {
			$x3=0;
		    } else {
			$x3 = int($z / $nl * 10000) / 10000;
		    }
		    print OUTFILE2 "transcript\t$chr:$s-$e\t$z\t$x3\t$n2\t$tlen\t$y\n";
		} else {
		    print OUTFILE1 "$y\t$st\n";
		    print OUTFILE1 "      Type\tLocation           \tmin\tmax\tLength\n";
		    print OUTFILE1 "transcript\t$chr:$s-$e\t$n1\t$n2\t$tlen";
		    my $info = "";
		    if($infofile_given eq "true") {
			my @b = split(/:::/,$y);
			for(my $k=0; $k<@b; $k++) {
			    $b[$k] =~ s/\(.*//;
			    $info = $INFO{$b[$k]};
			    if($info =~ /\S/) {
				$k=@b;
			    }
			}
			print OUTFILE1 "\t$info";
		    }
		    print OUTFILE1 "\n";
		}
	    } else {
		print OUTFILE1 "transcript\t$chr:$s-$e\t$x1\t$x2\t$tlen\t$st\t$y";
		my $info = "";
		if($infofile_given eq "true") {
		    my @b = split(/:::/,$y);
		    for(my $k=0; $k<@b; $k++) {
			$b[$k] =~ s/\(.*//;
			$info = $INFO{$b[$k]};
			if($info =~ /\S/) {
			    $k=@b;
			}
		    }
		    print OUTFILE1 "\t$info";
		}
		print OUTFILE1 "\n";
	    }
	    my $N = @{$TRANSCRIPT{$chr}[$i]{coords}};
	    if($st eq '+') {
		for(my $j=0; $j<$N; $j=$j+2) {
		    my $s = $TRANSCRIPT{$chr}[$i]{coords}[$j];
		    my $e = $TRANSCRIPT{$chr}[$i]{coords}[$j+1];
		    my $exon = $chr . ":" . $s . "-" . $e;
		    my $elen = $e - $s + 1;
		    my $nl = $elen / 1000;
		    my $x1 = $EXONhash{$exon}{u};
		    my $x2 = $EXONhash{$exon}{nu};
		    my $z = $x1 + $x2;
		    my $n1;
		    my $n2;
		    if($nl==0 || $nr==0) {
			$n1=0;
			$n2=0;
		    } else {
			$n1 = int($x1 / $nl / $nr * 10000) / 10000;
			$n2 = int($z / $nl / $nr * 10000) / 10000;
		    }
		    my $en = $j/2+1;
		    if($countsonly eq "false") {
			if($sepout eq "true") {
			    my $x3;
			    if($nl == 0) {
				$x3 = 0;
			    } else {
				$x3 = int($x1 / $nl * 10000) / 10000;
			    }
			    print OUTFILE1 "  exon $en\t$chr:$s-$e\t$x1\t$x3\t$n1\t$elen\n";
			    if($nl == 0) {
				$x3=0;
			    } else {
				$x3 = int($z / $nl * 10000) / 10000;
			    }
			    print OUTFILE2 "  exon $en\t$chr:$s-$e\t$z\t$x3\t$n2\t$elen\n";
			} else {
			    print OUTFILE1 "  exon $en\t$chr:$s-$e\t$n1\t$n2\t$elen\n";
			}
		    } else {
			print OUTFILE1 "exon\t$chr:$s-$e\t$x1\t$x2\t$elen\n";
		    }
		    if($j<$N-2) {
			my $s = $TRANSCRIPT{$chr}[$i]{coords}[$j+1]+1;
			my $e = $TRANSCRIPT{$chr}[$i]{coords}[$j+2]-1;
			my $intron = $chr . ":" . $s . "-" . $e;
			my $ilen = $e - $s + 1;
			my $nl = $ilen / 1000;
			my $x1 = $INTRONhash{$intron}{u};
			my $x2 = $INTRONhash{$intron}{nu};
			my $z = $x1 + $x2;
			my $n1;
			my $n2;
			if($nl==0 || $nr==0) {
			    $n1=0;
			    $n2=0;
			} else {
			    $n1 = int($x1 / $nl / $nr * 10000) / 10000;
			    $n2 = int($z / $nl / $nr * 10000) / 10000;
			}
			my $en = $j/2+1;
			if($countsonly eq "false") {
			    if($sepout eq "true") {
				my $x3;
				if($nl==0) {
				    $x3=0;
				} else {
				    $x3 = int($x1 / $nl * 10000) / 10000;
				}
				print OUTFILE1 "intron $en\t$chr:$s-$e\t$x1\t$x3\t$n1\t$ilen\n";
				if($nl==0) {
				    $x3=0;
				} else {
				    $x3 = int($z / $nl * 10000) / 10000;
				}
				print OUTFILE2 "intron $en\t$chr:$s-$e\t$z\t$x3\t$n2\t$ilen\n";
			    } else {
				print OUTFILE1 "intron $en\t$chr:$s-$e\t$n1\t$n2\t$ilen\n";
			    }
			} else {
			    print OUTFILE1 "intron\t$chr:$s-$e\t$x1\t$x2\t$ilen\n";
			}
		    }
		}
	    } else {
		for(my $j=0; $j<$N; $j=$j+2) {
		    my $s = $TRANSCRIPT{$chr}[$i]{coords}[($N-1)-($j+1)];
		    my $e = $TRANSCRIPT{$chr}[$i]{coords}[($N-1)-($j)];
		    my $exon = $chr . ":" . $s . "-" . $e;
		    my $x1 = $EXONhash{$exon}{u};
		    my $x2 = $EXONhash{$exon}{nu};
		    my $z = $x1 + $x2;
		    my $en = $j/2+1;
		    my $elen = $e - $s + 1;
		    my $nl = $elen / 1000;
		    my $n1;
		    my $n2;
		    if($nl==0 || $nr==0) {
			$n1 = 0;
			$n2 = 0;
		    } else {
			$n1 = int($x1 / $nl / $nr * 10000) / 10000;
			$n2 = int($z / $nl / $nr * 10000) / 10000;
		    }
		    if($countsonly eq "false") {
			if($sepout eq "true") {
			    my $x3;
			    if($nl==0) {
				$x3=0;
			    } else {
				$x3 = int($x1 / $nl * 10000) / 10000;
			    }
			    print OUTFILE1 "  exon $en\t$chr:$s-$e\t$x1\t$x3\t$n1\t$elen\n";
			    if($nl == 0) {
				$x3=0;
			    } else {
				$x3 = int($z / $nl * 10000) / 10000;
			    }
			    print OUTFILE2 "  exon $en\t$chr:$s-$e\t$z\t$x3\t$n2\t$elen\n";
			} else {
			    print OUTFILE1 "  exon $en\t$chr:$s-$e\t$n1\t$n2\t$elen\n";
			}
		    } else {
			print OUTFILE1 "exon\t$chr:$s-$e\t$x1\t$x2\t$elen\n";
		    }
		    if($j<$N-2) {
			my $s = $TRANSCRIPT{$chr}[$i]{coords}[($N-1)-($j+2)]+1;
			my $e = $TRANSCRIPT{$chr}[$i]{coords}[($N-1)-($j+1)]-1;
			my $intron = $chr . ":" . $s . "-" . $e;
			my $ilen = $e - $s + 1;
			my $nl = $ilen / 1000;
			my $x1 = $INTRONhash{$intron}{u};
			my $x2 = $INTRONhash{$intron}{nu};
			my $z = $x1 + $x2;
			my $n1;
			my $n2;
			if($nl == 0 || $nr == 0) {
			    $n1 = 0;
			    $n2 = 0;
			} else {
			    $n1 = int($x1 / $nl / $nr * 10000) / 10000;
			    $n2 = int($z / $nl / $nr * 10000) / 10000;
			}
			my $en = $j/2+1;
			if($countsonly eq "false") {
			    if($sepout eq "true") {
				my $x3;
				if($nl == 0) {
				    $x3 = 0;
				} else {
				    $x3 = int($x1 / $nl * 10000) / 10000;
				}
				print OUTFILE1 "intron $en\t$chr:$s-$e\t$x1\t$x3\t$n1\t$ilen\n";
				if($nl == 0) {
				    $x3 = 0;
				} else {
				    $x3 = int($z / $nl * 10000) / 10000;
				}
				print OUTFILE2 "intron $en\t$chr:$s-$e\t$z\t$x3\t$n2\t$ilen\n";
			    } else {
				print OUTFILE1 "intron $en\t$chr:$s-$e\t$n1\t$n2\t$ilen\n";
			    }
			} else {
			    print OUTFILE1 "intron\t$chr:$s-$e\t$x1\t$x2\t$ilen\n";
			}
		    }
		}
	    }
	}
    }
}

sub readfile () {
    my ($filename, $type) = @_;
    open(INFILE, $filename) or die "ERROR: in script rum2quantifications.pl: cannot open '$filename' for reading.\n\n";
    my %HASH;
    my $counter=0;
    my $line;
    my %indexstart_t;
    my %indexstart_e;
    my %indexstart_i;
    foreach my $chr (keys %TRANSCRIPT) {
	$indexstart_t{$chr} = 0;
	$indexstart_e{$chr} = 0;
	$indexstart_i{$chr} = 0;
    }
    while($line = <INFILE>) {
	$counter++;
#	if($counter % 100000 == 0 && $countsonly eq "false") {
#	    print "$type: counter=$counter\n";
#	}
	chomp($line);
	if($line eq '') {
	    last;
	}
	my @a = split(/\t/,$line);
	my $STRAND = $a[3];
	$a[0] =~ /(\d+)/;
	my $seqnum1 = $1;
	$READS[$seqnum1]=1;
	if($strandspecific eq 'true') {
	    if($strand eq 'p' && $STRAND eq '-' && $anti eq 'false') {
		next;
	    }
	    if($strand eq 'm' && $STRAND eq '+' && $anti eq 'false') {
		next;
	    }
	    if($strand eq 'p' && $STRAND eq '+' && $anti eq 'true') {
		next;
	    }
	    if($strand eq 'm' && $STRAND eq '-' && $anti eq 'true') {
		next;
	    }
	}
	my $CHR = $a[1];
	$HASH{$CHR}++;
#	if($HASH{$CHR} == 1) {
#	    print "CHR: $CHR\n";
#	}
	$a[2] =~ /^(\d+)-/;
	my $start = $1;
	my $end;
	my $line2 = <INFILE>;
	chomp($line2);
	my @b = split(/\t/,$line2);
	$b[0] =~ /(\d+)/;
	my $seqnum2 = $1;
	my $spans_union;
	
	if($seqnum1 == $seqnum2 && $b[0] =~ /b/ && $a[0] =~ /a/) {
	    if($a[3] eq "+") {
		$b[2] =~ /-(\d+)$/;
		$end = $1;
	    } else {
		$b[2] =~ /^(\d+)-/;
		$start = $1;
		$a[2] =~ /-(\d+)$/;
		$end = $1;
	    }
	    my $SPANS = &union($a[2], $b[2]);
	    @B = split(/[^\d]+/,$SPANS);
	} else {
	    $a[2] =~ /-(\d+)$/;
	    $end = $1;
	    # reset the file handle so the last line read will be read again
	    my $len = -1 * (1 + length($line2));
	    seek(INFILE, $len, 1);
	    @B = split(/[^\d]+/,$a[2]);
	}
	while($TRANSCRIPT{$CHR}[$indexstart_t{$CHR}]{end} < $start && $indexstart_t{$CHR} <= $tcnt{$CHR}) {
	    $indexstart_t{$CHR}++;	
	}
	while($EXON{$CHR}[$indexstart_e{$CHR}]{end} < $start && $indexstart_e{$CHR} <= $ecnt{$CHR}) {
	    $indexstart_e{$CHR}++;	
	}
	while($INTRON{$CHR}[$indexstart_i{$CHR}]{end} < $start && $indexstart_i{$CHR} <= $icnt{$CHR}) {
	    $indexstart_i{$CHR}++;	
	}
	my $i = $indexstart_t{$CHR};
	my $flag = 0;
	while($flag == 0) {
	    $tcnt{$CHR} = $tcnt{$CHR}+0;
	    if($end < $TRANSCRIPT{$CHR}[$i]{start} || $i >= $tcnt{$CHR}) {
		last;
	    }
	    @A = @{$TRANSCRIPT{$CHR}[$i]{coords}};
	    my $b = &do_they_overlap();
	    if($b == 1) {
		$TRANSCRIPT{$CHR}[$i]{$type}++;
	    }
	    $i++;
	}
	$i = $indexstart_e{$CHR};
	$flag = 0;
	while($flag == 0) {
	    $ecnt{$CHR} = $ecnt{$CHR}+0;
	    if($end < $EXON{$CHR}[$i]{start} || $i >= $ecnt{$CHR}) {
		last;
	    }
	    undef @A;
	    $A[0] = $EXON{$CHR}[$i]{start};
	    $A[1] = $EXON{$CHR}[$i]{end};
	    my $b = &do_they_overlap();
	    if($b == 1) {
		$EXON{$CHR}[$i]{$type}++;
	    }
	    $i++;
	}
	$i = $indexstart_i{$CHR};
	$flag = 0;
	while($flag == 0) {
	    $icnt{$CHR} = $icnt{$CHR}+0;
	    if($end < $INTRON{$CHR}[$i]{start} || $i >= $icnt{$CHR}) {
		last;
	    }
	    undef @A;
	    $A[0] = $INTRON{$CHR}[$i]{start};
	    $A[1] = $INTRON{$CHR}[$i]{end};
	    my $b = &do_they_overlap();
	    if($b == 1) {
		$INTRON{$CHR}[$i]{$type}++;
	    }
	    $i++;
	}
    }
}

sub do_they_overlap() {
    # going to pass in two arrays as global vars, because don't want them
    # to be copied every time, this function is going to be called a lot.
    # the global vars @A and @B

    my $i=0;
    my $j=0;

    while(1==1) {
	until(($B[$j] < $A[$i] && $i%2==0) || ($B[$j] <= $A[$i] && $i%2==1)) {
	    $i++;
	    if($i == @A) {
		if($B[$j] == $A[@A-1]) {
		    return 1;
		} else {
		    return 0;
		}
	    }
	}
	if(($i-1) % 2 == 0) {
	    return 1;
	} else {
	    $j++;
	    if($j%2==1 && $A[$i] <= $B[$j]) {
		return 1;
	    }
	    if($j >= @B) {
		return 0;
	    }
	}
    }
}

sub isroman($) {
    my $arg = shift;
    $arg ne '' and
      $arg =~ /^(?: M{0,3})
                (?: D?C{0,3} | C[DM])
                (?: L?X{0,3} | X[LC])
                (?: V?I{0,3} | I[VX])$/ix;
}

sub arabic($) {
    my $arg = shift;
    my %roman2arabic = qw(I 1 V 5 X 10 L 50 C 100 D 500 M 1000);
    my %roman_digit = qw(1 IV 10 XL 100 CD 1000 MMMMMM);
    my @figure = reverse sort keys %roman_digit;
    $roman_digit{$_} = [split(//, $roman_digit{$_}, 2)] foreach @figure;
    isroman $arg or return undef;
    my $last_digit = 1000;
    my $arabic=0;
    foreach (split(//, uc $arg)) {
        my ($digit) = $roman2arabic{$_};
        $arabic -= 2 * $last_digit if $last_digit < $digit;
        $arabic += ($last_digit = $digit);
    }
    $arabic;
}

sub cmpChrs () {
    my $a2_c = lc($b);
    my $b2_c = lc($a);
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
	my $a2_roman = $1;
	$b2_c =~ /chr([ivx]+)/;
	my $b2_roman = $1;
	my $a2_arabic = arabic($a2_roman);
    	my $b2_arabic = arabic($b2_roman);
	if($a2_arabic > $b2_arabic) {
	    return -1;
	} 
	if($a2_arabic < $b2_arabic) {
	    return 1;
	}
	if($a2_arabic == $b2_arabic) {
	    my $tempa = $a2_c;
	    my $tempb = $b2_c;
	    $tempa =~ s/chr([ivx]+)//;
	    $tempb =~ s/chr([ivx]+)//;
	    my %temphash;
	    $temphash{$tempa}=1;
	    $temphash{$tempb}=1;
	    foreach my $tempkey (sort {cmpChrs($a,$b)} keys %temphash) {
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
        my $numa = $1;
        if($b2_c =~ /chr(\d+)/) {
            my $numb = $1;
            if($numa < $numb) {return 1;}
	    if($numa > $numb) {return -1;}
	    if($numa == $numb) {
		my $tempa = $a2_c;
		my $tempb = $b2_c;
		$tempa =~ s/chr\d+//;
		$tempb =~ s/chr\d+//;
		my %temphash;
		$temphash{$tempa}=1;
		$temphash{$tempb}=1;
		foreach my $tempkey (sort {cmpChrs($a,$b)} keys %temphash) {
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
        my $letter_a = $1;
        if($b2_c =~ /chr([a-z]+)/) {
            my $letter_b = $1;
            if($letter_a lt $letter_b) {return 1;}
	    if($letter_a gt $letter_b) {return -1;}
        } else {
            return -1;
        }
    }
    my $flag_c = 0;
    while($flag_c == 0) {
        $flag_c = 1;
        if($a2_c =~ /^([^\d]*)(\d+)/) {
            my $stem1_c = $1;
            my $num1_c = $2;
            if($b2_c =~ /^([^\d]*)(\d+)/) {
                my $stem2_c = $1;
                my $num2_c = $2;
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

sub union () {
    my ($spans1_u, $spans2_u) = @_;

    my %chash;
    my @a = split(/, /,$spans1_u);
    for(my $i=0;$i<@a;$i++) {
	my @b = split(/-/,$a[$i]);
	for(my $j=$b[0];$j<=$b[1];$j++) {
	    $chash{$j}++;
	}
    }
    @a = split(/, /,$spans2_u);
    for(my $i=0;$i<@a;$i++) {
	my @b = split(/-/,$a[$i]);
	for(my $j=$b[0];$j<=$b[1];$j++) {
	    $chash{$j}++;
	}
    }
    my $first = 1;
    my $spans_union;
    my $pos_prev;
    foreach my $pos (sort {$a<=>$b} keys %chash) {
	if($first == 1) {
	    $spans_union = $pos;
	    $first = 0;
	} else {
	    if($pos > $pos_prev + 1) {
		$spans_union = $spans_union . "-$pos_prev, $pos";
	    }
	}
	$pos_prev = $pos;
    }
    $spans_union = $spans_union . "-$pos_prev";
    return $spans_union;
}

# seq.35669       chr1    3206742-3206966 -       GCCCACCACCATGTCAAACACAATCTCTTCCCATTTGGTGATACAGAATTCTGTCTCACAGTGGACAATCCAGAAAGTCATGATGCACCAATGGAGGACAATAAATATCCCAAAATACAGCTGGAAAACCGAGGCAAAGAGGGCGAATGTGATGACCCTGGCAGCGATGGTGAAGAAATGCCAGCAGAACTGAATGATGACAGCCATTTAGCTGATGGGCTTTTT
# 
# 
# chr1    -       3195981 3206425 2       3195981,3203689,        3197398,3206425,        OTTMUST00000086625(vega)
