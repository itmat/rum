#!/usr/bin/perl

# Written by Gregory R. Grant
# University of Pennsylvania, 2010

use Pod::Usage;
use RUM::Common qw(modify_fa_to_have_seq_on_one_line);

=pod

Usage: modify_fa_to_have_seq_on_one_line.pl <fasta file>

This modifies a fasta file to have the sequence all on one line.  
Outputs to standard out.

=cut

if(@ARGV < 1) {
    pod2usage();
}

open($infile, $ARGV[0]);
RUM::Common::modify_fa_to_have_seq_on_one_line($infile, STDOUT);
close(INFILE);
