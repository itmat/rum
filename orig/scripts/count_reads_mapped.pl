open(INFILE, $ARGV[0]);
if(!($ARGV[0]=~/\S/)) {
    print "\nUsage: count_reads_mapped.pl <filename of unique mappers> <filename of non-unique mappers>\n\nFile lines should look like this:\nseq.6b  chr19   44086924-44086960, 44088066-44088143    CGTCCAATCACACGATCAAGTTCTTCATGAACTTTGG:CTTGCACCTCTGGATGCTTGACAAGGAGCAGAAGCCCGAATCTCAGGGTGGTGCTGGTTGTCTCTGTGACTGCCGTAA\n\n";
    exit();
}
$max_seq_num = 0;
$flag = 0;
$num_areads = 0;
$num_breads = 0;
while($line = <INFILE>) {
    chomp($line);
    $line =~ /seq.(\d+)([^\d])/;
    $seqnum = $1;
    if($flag == 0) {
	$flag = 1;
	$min_seq_num = $seqnum;
    }
    if($seqnum > $max_seq_num) {
	$max_seq_num = $seqnum;
    }
    if($seqnum < $min_seq_num) {
	$min_seq_num = $seqnum;
    }
    $type = $2;
    if($type eq "\t") {
	$joined{$seqnum}++;
	$numjoined++;
	if($joined{$seqnum} > 1) {
	    print "SOMETHING IS WRONG: $seqnum ($joined{$seqnum}) $line\n";
	}
    }
    if($type eq "a" || $type eq "b") {
	$unjoined{$seqnum}++;
	if($unjoined{$seqnum} > 1) {
	    $num_unjoined_consistent++;
	}
	if($unjoined{$seqnum} > 2) {
	    print "SOMETHING IS WRONG: $seqnum ($unjoined{$seqnum}) $line\n";
	}
    }
    if($type eq "a") {
	$typea{$seqnum}++;
	$num_areads++;
	if($typea{$seqnum} > 1) {
	    print "SOMETHING IS WRONG: $seqnum ($typea{$seqnum}) $line\n";
	}
    }
    if($type eq "b") {
	$typeb{$seqnum}++;
	$num_breads++;
	if($typeb{$seqnum} > 1) {
	    print "SOMETHING IS WRONG: $seqnum ($typeb{$seqnum}) $line\n";
	}
    }
    $prev_line = $line;
}
close(INFILE);
foreach $key (keys %typea) {
    if($typeb{$key} == 0) {
	$num_a_only++;
    }
}
foreach $key (keys %typeb) {
    if($typea{$key} == 0) {
	$num_b_only++;
    }
}

$f = format_large_int($seqnum);
$total=$max_seq_num - $min_seq_num + 1;
$f = format_large_int($total);
print "Num reads total: $f\n";
if($num_breads > 0) {
    print "\nUNIQUE MAPPERS\n--------------\n";
    $num_bothmapped = $numjoined + $num_unjoined_consistent;
    $f = format_large_int($num_bothmapped);
    $percent_bothmapped = int($num_bothmapped/ $total * 10000) / 100;
    print "Both forward and reverse mapped consistently: $f ($percent_bothmapped%)\n";
    $f = format_large_int($numjoined);
    print "   - do overlap: $f\n";
    $f = format_large_int($num_unjoined_consistent);
    print "   - don't overlap: $f\n";
    $f = format_large_int($num_a_only);
    print "Num forward mapped only: $f\n";
}
$f = format_large_int($num_b_only);
if($num_breads > 0) {
    print "Num reverse mapped only: $f\n";
}
$num_a_total = $num_a_only + $num_bothmapped;
$num_b_total = $num_b_only + $num_bothmapped;
$f = format_large_int($num_a_total);
$percent_a_mapped = int($num_a_total / $total * 10000) / 100;
if($num_breads > 0) {
    print "Num forward total: $f ($percent_a_mapped%)\n";
}
else {
    print "UNIQUE MAPPERS: $f ($percent_a_mapped%)\n";
}
$f = format_large_int($num_b_total);
$percent_b_mapped = int($num_b_total / $total * 10000) / 100;
if($num_breads > 0) {
    print "Num reverse total: $f ($percent_b_mapped%)\n";
}
$at_least_one_of_forward_or_reverse_mapped = $num_bothmapped + $num_a_only + $num_b_only;
$f = format_large_int($at_least_one_of_forward_or_reverse_mapped);
$percent_at_least_one_of_forward_or_reverse_mapped = int($at_least_one_of_forward_or_reverse_mapped/ $total * 10000) / 100;
if($num_breads > 0) {
    print "At least one of forward or reverse mapped: $f ($percent_at_least_one_of_forward_or_reverse_mapped%)\n";
    print "\n";
}

open(INFILE, $ARGV[1]);
while($line = <INFILE>) {
    chomp($line);
    $line =~ /seq.(\d+)(.)/;
    $seqnum = $1;
    $type = $2;
    if($type eq "a") {
	$ambiga{$seqnum}++;
    }
    if($type eq "b") {
	$ambigb{$seqnum}++;
    }
    if($type eq "\t") {
	$ambiga{$seqnum}++;
	$ambigb{$seqnum}++;
    }
    $allids{$seqnum}++;
}
close(INFILE);

$num_ambig_consistent=0;
$num_ambig_a_only=0;
$num_ambig_b_only=0;
foreach $seqnum (keys %allids) {
    if($ambiga{$seqnum}+0 > 0 && $ambigb{$seqnum}+0 > 0) {
	$num_ambig_consistent++;	
    }
    if($ambiga{$seqnum}+0 > 0 && $ambigb{$seqnum}+0 == 0) {
	$num_ambig_a++;
    }
    if($ambiga{$seqnum}+0 == 0 && $ambigb{$seqnum}+0 > 0) {
	$num_ambig_b++;
    }
}
$f = format_large_int($num_ambig_a);
$p = int($num_ambig_a/$total * 1000) / 10;
if($num_breads > 0) {
    print "\nNON-UNIQUE MAPPERS\n------------------\n";
    print "Total number forward only ambiguous: $f ($p%)\n";
}
else {
    print "NON-UNIQUE MAPPERS: $f ($p%)\n";
}
$f = format_large_int($num_ambig_b);
$p = int($num_ambig_b/$total * 1000) / 10;
if($num_breads > 0) {
    print "Total number reverse only ambiguous: $f ($p%)\n";
}
$f = format_large_int($num_ambig_consistent);
$p = int($num_ambig_consistent/$total * 1000) / 10;
if($num_breads > 0) {
    print "Total number consistent ambiguous: $f ($p%)\n";
    print "\n";
    print "\nTOTAL\n-----\n";
}

$num_forward_total = $num_a_total + $num_ambig_a + $num_ambig_consistent;
$num_reverse_total = $num_b_total + $num_ambig_b + $num_ambig_consistent;
$num_consistent_total = $num_bothmapped + $num_ambig_consistent;
$f = format_large_int($num_forward_total);
$p = int($num_forward_total/$total * 1000) / 10;
if($num_breads > 0) {
    print "Total number forward: $f ($p%)\n";
}
else {
    print "TOTAL: $f ($p%)\n";
}
$f = format_large_int($num_reverse_total);
$p = int($num_reverse_total/$total * 1000) / 10;
if($num_breads > 0) {
    print "Total number reverse: $f ($p%)\n";
}
$f = format_large_int($num_consistent_total);
$p = int($num_consistent_total/$total * 1000) / 10;
if($num_breads > 0) {
    print "Total number consistent: $f ($p%)\n";
}
$total_fragment = $at_least_one_of_forward_or_reverse_mapped + $num_ambig_a + $num_ambig_b + $num_ambig_consistent;
$f = format_large_int($total_fragment);
$p = int($total_fragment/$total * 1000) / 10;
if($num_breads > 0) {
    print "At least one of forward or reverse mapped: $f ($p%)\n";
}

sub format_large_int () {
    ($int) = @_;
    @a = split(//,"$int");
    $j=0;
    $newint = "";
    $n = @a;
    for($i=$n-1;$i>=0;$i--) {
	$j++;
	$newint = $a[$i] . $newint;
	if($j % 3 == 0) {
	    $newint = "," . $newint;
	}
    }
    $newint =~ s/^,//;
    return $newint;
}
