
if(@ARGV < 1) {
    die "
Usage: get_nu_stats.pl <sam file>

";
}

$samfile = $ARGV[0];

open(INFILE, $samfile);

$doing = "seq.0";
while($line = <INFILE>) {
    if($line =~ /LN:\d+/) {
	next;
    } else {
	last;
    }
}
while($line = <INFILE>) {
    $line =~ /^(\S+)\t.*IH:i:(\d+)\s/;
    $id = $1;
    $cnt = $2;
    if(!($line =~ /IH:i:\d+/)) {
	$doing = $id;
	next;
    }
#    print "id=$id\n";
#    print "cnt=$cnt\n";
    if($doing eq $id) {
	next;
    } else {
	$doing = $id;
	$hash{$cnt}++;
    }
}
close(INFILE);

print "num_locs\tnum_reads\n";
foreach $cnt (sort {$a<=>$b} keys %hash) {
    print "$cnt\t$hash{$cnt}\n";
}
