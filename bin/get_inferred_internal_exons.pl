#!/usr/bin/perl

# Written by Gregory R. Grant
# University of Pennsylvania, 2010

use strict;
use warnings;
use FindBin qw($Bin);
use lib ("$Bin/../lib", "$Bin/../lib/perl5");
use RUM::Script;
RUM::Script->run_with_logging("RUM::Script::GetInferredInternalExons");

=head1 NAME

get_inferred_internal_exons.pl

=head1 SYNOPSIS

get_inferred_internal_exons.pl [OPTIONS] --junctions <junctions file> --coverage <coverage file> --genes <annot file> 

=head1 OPTIONS

=over 4

=item B<--junctions> I<junctions_file>

The high-quality junctions file output by RUM, sorted by chromosome
(it should be sorted already when it comes out of RUM).  It does not
matter what gene annotation was used to generate it, the annotation
used to aid in inferring exons is taken from the <annnot file>
parameter.

=item B<--coverage> I<coverage_file>

The coverage file output by RUM, sorted by chromosome (it should be
sorted already when it comes out of RUM).

=item B<--genes> I<annot_file>

Transcript models file, in the format of the RUM gene info file.

=item B<--min-score> I<n>

Don't use junctions unless they have at least this score (default =
1).  Note: this will only be applied to things with coverage at the
junction of at least 5 times the minscore.

=item B<--max-exon> I<n>

Don't infer exons larger than this (default = 500 bp).

=item B<--bed> I<f>

Output as bed file to file named f

=back
