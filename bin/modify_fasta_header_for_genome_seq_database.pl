#!/usr/bin/perl

# Written by Gregory R. Grant
# University of Pennsylvania, 2010

=head1 NAME

modify_fasta_header_for_genome_seq_database

=head1 SYNOPSIS

modify_fasta_header_for_genome_seq_database.pl F<fasta_file>

=head1 DESCRIPTION

This expects a fasta file with header that looks like:

    >hg19_ct_UserTrack_3545_+ range=chrUn_gl000248:1-39786 ...

and it modifies it to look like this:

    >chrUn_gl000248

This script is part of the pipeline of scripts used to create RUM indexes.
You should probably not be running it alone.  See the library file:
'how2setup_genome-indexes_forPipeline.txt'.

=cut

use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::Index qw(transform_input
                   modify_fasta_header_for_genome_seq_database);

transform_input(\&modify_fasta_header_for_genome_seq_database);
