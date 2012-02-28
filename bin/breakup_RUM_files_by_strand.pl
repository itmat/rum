#!/usr/bin/env perl

use strict;
no warnings;

my ($infile, $outfile1, $outfile2) = @ARGV;

open my $in,  "<", $infile;
open my $out1, ">", $outfile1;
open my $out2, ">", $outfile2;

while (defined(my $line = <$in>)) {
    if ($line =~ /\t-\t/) {
        print $out2 $line;
    } else {
	print $out1 $line;
    }
}
