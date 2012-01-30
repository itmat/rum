
if(@ARGV < 2) {
    die "
Usage: perl get_junction_reads.pl <rum file> <chr:start-end> [option]
   or: perl get_junction_reads.pl <rum file> <chr> <start> <end> [option]

Options: -i : intron coords        (see below for more info)
         -b : bedfile ucsc coords  (see below for more info)

'start' and 'end' can be any of the following:
1) The terminal coords of the exons
   * start is the most downstream coord of the upstream exon
   * end is the most upstream coord of the downstream exon
2) The terminal coords of the intron
   * start is the 
   * end is the most downstream coords of the intron
   (use the -i option in this case).
3) The coords given in the UCSC browser (if you click on the feature),
   for the RUM junctions bed file (use the -b option in that case).

NOTE 1: For best results pipe the output to 'less -S'.
NOTE 2: To speed things up, you might want to first filter out the reads
        from the rum file that don't cross junctions ('grep \", \" <file>'
        should do it).

";
}

$rumfile = $ARGV[0];

$i=0;
while(!($ARGV[$i] =~ /^-/) && $i < @ARGV) {
    $i++;
}

if($i == 4) {
    $CHR = $ARGV[1];
    $START = $ARGV[2];
    $END = $ARGV[3];
}
if($i == 2) {
    $ARGV[1] =~ /(.*):(\d+)-(\d+)/;
    $CHR = $1;
    $START = $2;
    $END = $3;
}
if($ARGV[$i] eq "-b") {
    $START = $START + 49;
    $END = $END - 49;
}
if($ARGV[$i] eq "-i") {
    $START = $START - 1;
    $END = $END + 1;
}

$hits = `grep \"$START, $END\" $rumfile | grep $CHR`;
chomp($hits);
@HITS = split(/\n/,$hits);
$max_length_left=0;
$max_length_right=0;
for($i=0; $i<@HITS; $i++) {
    @a = split(/\t/,$HITS[$i]);
    $coords[$i] = $a[2];
    $seq[$i] = $a[4];
    while($seq[$i] =~ /\+/) {
	$seq[$i] =~ s/^([^+]+)\+[^+]+\+/$1/;
    }
    while(!($coords[$i] =~ /^\d+-$START, /)) {
	$coords[$i] =~ s/^\d+-\d+, //;
	$seq[$i] =~ s/^[^:]+://;
    }
    while(!($coords[$i] =~ /, $END-\d+$/)) {
	$coords[$i] =~ s/, \d+-\d+$//;
	$seq[$i] =~ s/:[^:]+$//;
    }
    $coords[$i] =~ /(\d+)-(\d+), (\d+)-(\d+)/;
    $s1 = $1;
    $e1 = $2;
    $s2 = $3;
    $e2 = $4;
    if($e1 - $s1 + 1 > $max_length_left) {
	$max_length_left = $e1 - $s1 + 1;
    }
    if($e2 - $s2 + 1 > $max_length_right) {
	$max_length_right = $e2 - $s2 + 1;
    }
}
for($i=0; $i<@HITS; $i++) {
    $coords[$i] =~ /(\d+)-(\d+), (\d+)-(\d+)/;
    $s1 = $1;
    $e1 = $2;
    $s2 = $3;
    $e2 = $4;
    @SEQ = split(/:/,$seq[$i]);
    $prefix_length = $max_length_left - ($e1-$s1+1);
    for($j=0; $j<$prefix_length; $j++) {
	print " ";
    }
    print $SEQ[0];
    print "  ";
    print $SEQ[1];
    print "\n";
}
