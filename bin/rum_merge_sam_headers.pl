#!/usr/bin/env perl

use strict;
use warnings;
use FindBin qw($Bin);
use lib ("$Bin/../lib", "$Bin/../lib/perl5");
use RUM::Script;
RUM::Script->run_with_logging("RUM::Script::MergeSamHeaders");

=head1 NAME

rum_merge_sam_headers.pl

=head1 SYNOPSIS

  rum_merge_sam_headers sam_headers.1 [ ... sam_headers.n ] > out

=head1 DESCRIPTION

Merge together the SAM header files listed on the command line and
print the merged headers to stdout.

=cut
