#!/usr/bin/perl

# Written by Gregory R. Grant
# University of Pennsylvania, 2010

if(@ARGV < 1) {
    die "
Usage: sort_geneinfofile.pl <gene info file>

This script is part of the pipeline of scripts used to create RUM indexes.
You should probably not be running it alone.  See the library file:
'how2setup_genome-indexes_forPipeline.txt'.

";
}

open(INFILE, $ARGV[0]);
while($line = <INFILE>) {
    chomp($line);
    @a = split(/\t/,$line);
    $start{$line} = $a[2];
    $end{$line} = $a[3];
    $chr{$line} = $a[0];
}
close(INFILE);

foreach $line (sort {$chr{$a} cmp $chr{$b} || $start{$a}<=>$start{$b} || $end{$a}<=>$end{$b}} keys %start) {
    print "$line\n";
}
