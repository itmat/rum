
if(@ARGV<4) {
    die "
Usage: trim.pl <reads file> <pattern> <type> <minlength>

Where
    <reads file>: fasta or fastq file of sequences
    <pattern>: the pattern to trim on
    <type>: 'fasta' or 'fastq'
    <minlength>: if the trimmed length is less than this, it will not report the record at all

This script outputs to standard out.

";
}

$infile = $ARGV[0];
$pattern = $ARGV[1];
$type = $ARGV[2];
$minlength = $ARGV[3];

if($Minlength < 5) {
    die "Error: the <minlength> parameter must be at least 5\n\n";
}

@a = split(//,$pattern);

for($i=0; $i<@a; $i++) {
    $word[$i] = $pattern;
    substr($word[$i],$i,1,".");
}

open(INFILE, $infile) or die "Error: cannot open '$infile' for reading\n\n";
@PATTERN = split(//,$pattern);
$plength = @PATTERN;
if($type eq 'fasta') {
    while($IDline = <INFILE>) {
	$line = <INFILE>;
	chomp($line);
	$trimmed = &trim($line);
	if(length($trimmed) >= $minlength) {
	    print $IDline;
	    print "$trimmed\n";
	}
    }
}
if($type eq 'fastq') {
    print "here\n";
    while($line1 = <INFILE>) {
	$line2 = <INFILE>;
	chomp($line2);
	$trimmed = &trim($line2);
	$line3 = <INFILE>;
	$line4 = <INFILE>;
	chomp($line4);
	$length = length($trimmed);
	$readlength = length($line4);
	$diff = $readlength - $length;
	substr($line4, $length, $diff, "");
	if(length($trimmed) >= $minlength) {	
	    print $line1;
	    print "$trimmed\n";
	    print $line3;
	    print "$line4\n";
	}
    }
}

close(INFILE);

sub trim () {
    ($seq) = @_;

    $success = 0;
    if(!($seq =~ s/$pattern.*//)) {
	for($i=0; $i<@word; $i++) {
	    $STR = $word[$i];
	    if($seq =~ s/$STR.*//) {
		$i = @word;
		$success = 1;
	    }
	}
    } else {
	$success = 1;
    }

    if($success == 0) {
	@a = split(//,$seq);
	$llength = @a;
	$max_score = 0;
	$second_max = 0;
	$max_index = "";
	for($j=0; $j<$llength; $j++) {
	    if($llength-$j < $plength) {
		$N = $llength-$j;
	    } else {
		$N = $plength;
	    }
	    $score[$j]=0;
	    for($k=0; $k<$N; $k++) {
		if($a[$j+$k] eq $PATTERN[$k]) {
		    $score[$j]++;
		}
	    }
	    if($score[$j] > $max_score) {
		$max_score = $score[$j];
		$max_index = $j;
	    }
	    if($score[$j] < $max_score && $score[$j] >= $second_max) {
		$second_max = $score[$j];
	    }
	}
	if($max_score >= $second_max * 1.5 && $max_score >= $plength * .65) {
	    substr($seq, $max_index, $llength - $max_index, "");
	}
    }
    return $seq;
}
