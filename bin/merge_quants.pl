#!/usr/bin/perl

# Written by Gregory R Grant
# University of Pennsylvania, 2010

use strict;
use warnings;
use FindBin qw($Bin);
use lib ("$Bin/../lib", "$Bin/../lib/perl5");
use RUM::Script;
RUM::Script->run_with_logging("RUM::Script::MergeQuants");

=head1 NAME

merge_quants.pl - Merge quantification reports

=head1 SYNOPSIS

merge_quants.pl [OPTIONS] -n <num_chunks> -o <outfile> <dir>

=head1 DESCRIPTION

This script will look in F<dir> for files named quant.1, quant.2,
etc..  up to quant.numchunks.  Unless -strand S is set in which case
it looks for quant.S.1, quant.S.2, etc...

=head1 OPTIONS

=over 4

=item B<-n>, B<--chunks> I<num_chunks>

The number of chunks

=item B<-o>, B<--output> I<outfile>

The output file.

=item B<--strand> I<s>

ps, ms, pa, or ma (p: plus, m: minus, s: sense, a: antisense)

=item B<--chunk-ids-file> I<f>

If a file mapping chunk N to N.M.  This is used specifically for the
RUM pipeline when chunks were restarted and names changed.

=item B<--countsonly>

Output only a simple file with feature names and counts.

=item B<--alt>

Need this if using --altquant when running RUM

=back
