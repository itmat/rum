#!/usr/bin/env perl

use strict;
use warnings;
use FindBin qw($Bin);
use lib ("$Bin/../lib", "$Bin/../lib/perl5");
use RUM::Script;
RUM::Script->run_with_logging("RUM::Script::MakeRumJunctionsFile");

=head1 NAME

make_RUM_junctions_file.pl

=head1 DESCRIPTION

This script finds the junctions in the RUM_Unique and RUM_NU files
and reports them to a junctions file that can be uploaded to the UCSC
browser.

In the high quality junctions, junctions in the annotation file are
colored blue, others are colored green.  Those with standard splice
signals (or those specified by -signal) are colored a shade lighter.

=head1 SYNOPSIS

make_RUM_junctions_file.pl [OPTIONS] --sam-in <sam> --genome <genome seq> [--genes <gene annotations>] --all-rum-out <all junctions outfile rum-format> --all-bed-out <all junctions outfile bed-format> --high-quality-bed-out  <high quality junctions outfile bed-format>

=over 4

=item B<--sam-in> I<sam-in>

The sam file.

=item B<--genome> I<genome_seq>

The genome fasta file.

=item B<--genes> I<gene_annotations>

The RUM gene models file; omit there are no known gene
models.

=item B<--all-rum-out> I<all_junctions_rum_format>

The output file for all junctions in RUM format.

=item B<--all-bed-out> I<all_junctions_bed_format>

The output file for all junctions in bed format.

=item B<--high-quality-bed-out> I<high_quality_junctions_bed_format>

The output file for high-quality junctions in bed format.

=item B<--faok>

The fasta file already has sequence all on one line.

=item B<--min-intron> I<n>

The size of the smallest intron allowed. Must be > 0, default is 15 bp.

=item B<--overlap> I<n>

There must be at least this many bases spanning either side of a junction to qualify as high quality. Default is 8 bp.

=item B<--sam-out> I<sam-out>

If you want it to fix the sam file when it finds a junction that has an unknown (or non-canonical) splice signal and it
also happens to be ambiguous with the last base of the intron equaling the last base of the exon, or converseley, and
one of those alternate alignments does have a known (or canonical) splice signal.

=item B<--signal> I<wxyz>

Use this alternate splice signal; wx is the donor and yz is the acceptor. Multiple may be specified, separated by commas without whitespace. If not specified, the standard signals will be used, with the canonical colored darker in the high quality junctions file.

=item B<--strand> I<x>

Either p (for the plus strand) or m (for the minus strand).

=back

