#!/usr/bin/perl

=head1 NAME

make_ids_unique4geneinfofile

=head1 SYNOPSIS

make_ids_unique4geneinfofile.pl F<gene-info-file> > out.txt

=head1 DESCRIPTION

TODO

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
use lib ("$Bin/../lib", "$Bin/../lib/perl5");
use RUM::Script qw(:scripts get_options show_usage);

get_options();
show_usage() unless @ARGV == 1;
make_ids_unique4geneinfofile, $ARGV[0];
