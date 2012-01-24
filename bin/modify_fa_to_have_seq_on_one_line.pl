#!/usr/bin/perl

=head1 NAME

modify_fa_to_have_seq_on_one_line

=head1 SYNOPSIS

modify_fa_to_have_seq_on_one_line.pl F<fasta_file> > out.fa
modify_fa_to_have_seq_on_one_line.pl < in.fa > out.fa

=head1 DESCRIPTION

This modifies a fasta file to have the sequence all on one line. Reads
from either a file supplied on the command line of from stdin.
Outputs to standard out.

=head1 OPTIONS

=over 4

=item I<--help|-h>

Get help.

=back

=head1 ARGUMENTS

=over 4

=item F<fasta_file>

File to operate on.

=back

=head1 AUTHOR

Written by Gregory R. Grant, University of Pennsylvania, 2010

=cut

use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::Transform qw(transform_file get_options);
use RUM::Transform::Fasta qw(modify_fa_to_have_seq_on_one_line);

get_options();
transform_file \&modify_fa_to_have_seq_on_one_line;
