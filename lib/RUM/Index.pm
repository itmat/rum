package RUM::Index;

use strict;
use warnings;

use FindBin qw($Bin);
use Exporter 'import';
use Pod::Usage;
use Log::Log4perl qw(:easy);
use RUM::ChrCmp qw(cmpChrs sort_by_chromosome);

Log::Log4perl->easy_init($INFO);

our @EXPORT_OK = qw(run_bowtie);

=pod

=head1 NAME

RUM::Index - Common utilities for creating indexes for RUM.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

  use RUM::Index qw(run_bowtie)

  run_bowtie(...)

=head1 DESCRIPTION

Provides some common utilities for creating indexes for RUM.

=head2 Subroutines

=over 4

=cut

=item run_bowtie(@args)

Runs bowtie-build with the following arguments. Checks the return
status and dies if it's non-zero.

=cut
sub run_bowtie {
  my @cmd = ("bowtie-build", @_);
  print "Running @cmd\n";
  system @cmd;
  $? == 0 or die "Bowtie failed: $!";
}

=back

=head1 AUTHORS

=over 4

=item Gregory R. Grant

=item Mike DeLaurentis

=item University of Pennsylvania, 2010

=back

=cut
return 1;
