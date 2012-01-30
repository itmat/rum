if(@ARGV<1) {
    die "
Usage: sam2junctions.pl <sam file>

";
}

open(INFILE, $ARGV[0]) or die "\nError: Cannot open '$ARGV[0]' for reading\n\n";
$line = <INFILE>;
while($line =~ /^@/) {
    $line = <INFILE>;
}
while($line = <INFILE>) {
    chomp($line);
    @a = split(/\t/, $line);
    $sam_chr = $a[2];
    $sam_chr =~ s/:[^:]*$//;
    $sam_start = $a[3];
    $sam_cigar = $a[5];
    $running_offset = 0;
    while($sam_cigar =~ /^(\d+)([^\d])/) {
	$num = $1;
	$type = $2;
	if($type eq 'N') {
	    $start = $sam_start + $running_offset - 1;
	    $end = $start + $num + 1;
	    $junction = "$sam_chr:$start-$end";
	    print "$junction\n";
	}
	if($type eq 'N' || $type eq 'M' || $type eq 'D') {
	    $running_offset = $running_offset + $num;
	}
	$sam_cigar =~ s/^\d+[^\d]//;
    }
}
close(INFILE);
