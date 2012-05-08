#!/usr/bin/env perl

use strict;
use warnings;
use FindBin qw($Bin);
use lib ("$Bin/../lib", "$Bin/../lib/perl5");
use RUM::Script;
RUM::Script->run_with_logging("RUM::Script::MergeGnuAndTnuAndCnu");

=head1 NAME

merge_GNU_and_TNU_and_CNU.pl

=head1 SYNOPSIS

merge_GNU_and_TNU_and_CNU.pl --gnu-in <gnu_in> --tnu-in <tnu_in> --cnu_in <cnu_in> --output <bowtie_nu_out>

=head1 OPTIONS

=over 4

=item B<--gnu-in> I<gnu_in>

The file of non-unique mappers from the script make_GU_and_GNU.pl.

=item B<--tnu-in> I<tnu_in>

The file of non-unique mappers from the script make_TU_and_TNU.pl.

=item B<--cnu-in> I<cnu_in>

The file of non-unique mappers from the script merge_GU_and_TU.pl.

=item B<-o>, B<--output>  I<bowtie_nu_out>

The file of non-unique mappers to be output.

=back

=head1 AUTHOR

Mike DeLaurentis (delaurentis@gmail.com)

=head1 COPYRIGHT

Copyright 2012 University of Pennsylvania

=cut



