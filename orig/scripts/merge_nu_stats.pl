#!/usr/bin/perl

# Written by Gregory R Grant
# University of Pennsylvania, 2010

if(@ARGV<2) {
    die "
Usage: merge_nu_stats.pl <dir> <numchunks>

This script will look in <dir> for files named nu_stats.1, nu_stats.2, etc..
up to nu_stats.numchunks.  

Option:

    -chunk_ids_file f : If a file mapping chunk N to N.M.  This is used
                        specifically for the RUM pipeline when chunks were
                        restarted and names changed. 

";
}

$output_dir = $ARGV[0]; 
$numchunks = $ARGV[1];

for($i=2; $i<@ARGV; $i++) {
    $optionrecognized = 0;
    if($ARGV[$i] eq "-chunk_ids_file") {
	$chunk_ids_file = $ARGV[$i+1];
	$i++;
	if(-e "$chunk_ids_file") {
	    open(INFILE, "$chunk_ids_file") or die "Error: cannot open '$chunk_ids_file' for reading.\n\n";
	    while($line = <INFILE>) {
		chomp($line);
		@a = split(/\t/,$line);
		$chunk_ids_mapping{$a[0]} = $a[1];
	    }
	    close(INFILE);
	}
	$optionrecognized = 1;
    }
}


for($i=1; $i<=$numchunks; $i++) {

    $filename = "$output_dir/nu_stats.$i";
    if($chunk_ids_file =~ /\S/ && $chunk_ids_mapping{$i} =~ /\S/) {
	$filename = $filename . "." . $chunk_ids_mapping{$i};
    }
    open(INFILE, "$filename");
    $line = <INFILE>;
    while($line = <INFILE>) {
	chomp($line);
	@a = split(/\t/,$line);
	if(defined $hash{$a[0]}) {
	    $hash{$a[0]} = $hash{$a[0]} + $a[1];
	} else {
	    $hash{$a[0]} = $a[1];
	}
    }
}

print "\n------------------------------------------\n";
print "num_locs\tnum_reads\n";
foreach $cnt (sort {$a<=>$b} keys %hash) {
    print "$cnt\t$hash{$cnt}\n";
}
