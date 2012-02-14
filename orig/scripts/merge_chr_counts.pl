#!/usr/bin/perl

use FindBin qw($Bin);
use lib "$Bin/../../lib";

use RUM::Common qw(roman Roman isroman arabic);
use RUM::ChrCmp qw(by_chromosome);

if(@ARGV<2) {
    die "Usage: merge_chr_counts.pl <outfile> <infile1> <infile2> [<infile3> ... <infileN>] [option]

Where: the infiles are chr_counts files.  They will be merged into a single
sorted file output to <outfile>.

    Option:
           -chunk_ids_file f : If a file mapping chunk N to N.M.  This is used
                               specifically for the RUM pipeline when chunks were
                               restarted and names changed. 
";
}

$options = "false";
$numfiles = 0;
for($i=0; $i<@ARGV; $i++) {
    if($ARGV[$i] =~ /^-/) {
	$options = "true";
	$options_start_index = $i;
	$i = @ARGV;
    } else {
	$numfiles = $i;
    }
}

$chunk_ids_file = "";
if($options eq "true") {
    for($i=$options_start_index; $i<@ARGV; $i++) {
	if($ARGV[$i] eq '-chunk_ids_file') {
	    $chunk_ids_file = $ARGV[@ARGV-1];
	    if(-e $chunk_ids_file) {
		open(INFILE, $chunk_ids_file) or die "Error: cannot open '$chunk_ids_file' for reading.\n\n";
		while($line = <INFILE>) {
		    chomp($line);
		    @a = split(/\t/,$line);
		    $chunk_ids_mapping{$a[0]} = $a[1];
		}
		close(INFILE);
	    } else {

	    }
	}
    }
}
$outfile = $ARGV[0];
open(OUTFILE, ">>$outfile");

for($i=0; $i<$numfiles; $i++) {
    $file[$i] = $ARGV[$i+1];
    $j = $i+1;
    if($chunk_ids_file =~ /\S/ && $chunk_ids_mapping{$j} =~ /\S/) {
	$file[$i] =~ s/(\d|\.)+$//;
	$file[$i] = $file[$i] . ".$j." . $chunk_ids_mapping{$j};
    }
}

for($i=0; $i<$numfiles; $i++) {
    open(INFILE, $file[$i]);
    $line = <INFILE>;
    $line = <INFILE>;
    $line = <INFILE>;
    $line = <INFILE>;
    while($line = <INFILE>) {
	chomp($line);
	@a1 = split(/\t/,$line);
	$chrcnt{$a1[0]} = $chrcnt{$a1[0]} + $a1[1];
    }
    close(INFILE);
}

foreach $chr (sort by_chromosome keys %chrcnt) {
    $cnt = $chrcnt{$chr};
    print OUTFILE "$chr\t$cnt\n";
}



