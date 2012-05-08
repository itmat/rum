#!/usr/bin/env perl

use strict;
use warnings;
use FindBin qw($Bin);
use lib ("$Bin/../lib", "$Bin/../lib/perl5");
use RUM::Script;
RUM::Script->run_with_logging("RUM::Script::MakeUnmappedFile");

=head1 NAME

make_unmapped_file.pl - Build file of reads that remain unmapped after bowtie

=head1 SYNOPSIS

make_unmapped_file.pl --reads-in <reads-file> --unique-in <bowtie-unique-file> --non-unique-in <bowtie_nu_file> --unmapped-out <bowtie_unmapped_file> --paired|--single

=head1 DESCRIPTION

Reads in a reads file and files of unique and non-unique mappings
obtained from bowtie, and outputs a file of reads that remain
unmapped.

=head1 OPTIONS

=over 4

=item B<--reads-in> I<reads>

The fasta file of reads.

=item B<--unique-in> I<unique_in>

The file of unique mappers output from merge_GU_and_TU

=item B<--non-unique-in> I<non_unique_in>

The file of non-unique mappers output from merge_GNU_and_TNU_and_CNU

=item B<--single> | B<--paired>

Specify whether the input contains single-end reads or for paired-end
reads.

=item B<--umapped-out> I<unmapped_out>

The file to write unmapped reads to.

=item B<-v>, B<--verbose>

=item B<-q>, B<--quiet>

=item B<-h>, B<--help>

=back

=head1 AUTHOR

Gregory Grant (ggrant@grant.org)

=head1 COPYRIGHT

Copyright 2012 University of Pennsylvania

=cut
