#!/usr/bin/perl

=head1 NAME

fix_geneinfofile_for_neg_introns

=head1 SYNOPSIS

fix_geneinfofile_for_neg_introns.pl F<gene-info-file> F<starts-col> F<ends-col> F<num-exons-col> > out.txt

=head1 DESCRIPTION

This script takes a UCSC gene annotation file and outputs a file that removes
introns of zero or negative length.  You'd think there shouldn't be such introns
but for some annotation sets there are.

<starts col> is the column with the exon starts, <ends col> is the column with
the exon ends.  These are counted starting from zero.  <num exons col> is the
column that has the number of exons, also counted starting from zero.  If there
is no such column, set this to -1.

This script is part of the pipeline of scripts used to create RUM indexes.
For more information see the library file: 'how2setup_genome-indexes_forPipeline.txt'.

=head1 OPTIONS

=over 4

=item I<--help|-h>

Get help.

=back

=head1 ARGUMENTS

=over 4

=item F<gene-info-file>

File to operate on.

=back

=head1 AUTHOR

Written by Gregory R. Grant, University of Pennsylvania, 2010

=cut

use strict;
no warnings;

use FindBin qw($Bin);
use lib ("$Bin/../lib", "$Bin/../lib/perl5");
use RUM::Script qw(get_options show_usage :scripts);

get_options();
show_usage() unless @ARGV == 4;
my ($in, @args) = @ARGV;
fix_geneinfofile_for_neg_introns $in, undef, @args;
