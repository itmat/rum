#!/usr/bin/perl

# Written by Gregory R. Grant
# University of Pennsylvania, 2010

=head1 NAME

modify_fa_to_have_seq_on_one_line

=head1 SYNOPSIS

modify_fa_to_have_seq_on_one_line.pl F<fasta_file>

=head1 DESCRIPTION

This modifies a fasta file to have the sequence all on one line.  
Outputs to standard out.

=cut

use RUM::Common qw(transform_input
                   modify_fa_to_have_seq_on_one_line);

transform_input(\&modify_fa_to_have_seq_on_one_line);
