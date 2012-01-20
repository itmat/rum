open(INFILE, $ARGV[0]);
$|=1;
while($line = <INFILE>) {
    chomp($line);
    @a = split(/\t/,$line);
    if($a[2] ne 'exon') {
	next;
    }
    $line =~ /transcript_id ([^\s;]+)/;
    $transcript_id = $1;
    $transcript_id =~ s/"//g;
    $line =~ /gene_name ([^\s;]+)/;
    $gene_name = $1;
    $gene_name =~ s/"//g;
    $NAME = $transcript_id;
    if(!($NAME =~ /$gene_name/)) {
	$NAME = $gene_name . "_" . $transcript_id;
    }
    $chr{$NAME} = $a[0];
    $chr{$NAME} =~ s/"//g;
    $strand{$NAME} = $a[6];
    $strand{$NAME} =~ s/"//g;
    $start_adjusted = $a[3]-1;
    $starts{$NAME}{$start_adjusted}++;
    $ends{$NAME}{$a[4]}++;
}
close(FILE);
print "#name\tchrom\tstrand\texonStarts\texonEnds\n";
foreach $name (keys %starts) {
    $S="";
    $E="";
    foreach $s (sort {$a<=>$b} keys %{$starts{$name}}) {
	$S = $S . "$s,";
    }
    foreach $e (sort {$a<=>$b} keys %{$ends{$name}}) {
	$E = $E . "$e,";
    }
    print "$name\t$chr{$name}\t$strand{$name}\t$S\t$E\n";
}

# Mt      protein_coding  exon    273     734     .       -       .        gene_id "ATMG00010"; transcript_id "ATMG00010.1"; exon_number "1"; gene_name "ORF153A"; transcript_name "ATMG00010.1";
