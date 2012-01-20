#!/usr/bin/perl

# Written by Gregory R. Grant
# University of Pennsylvania, 2010

if(@ARGV < 1) {
    die "
Usage: modify_fa_to_have_seq_on_one_line.pl <fasta file>

This modifies a fasta file to have the sequence all on one line.  
Outputs to standard out.

";
}

open(INFILE, $ARGV[0]);
$flag = 0;
while($line = <INFILE>) {
    if($line =~ />/) {
        if($flag == 0) {
            print $line;
            $flag = 1;
        } else {
            print "\n$line";
        }
    } else {
        chomp($line);
        $line = uc $line;
        print $line;
    }
}
print "\n";
close(INFILE);
