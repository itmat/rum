package RUM::Workflow;

=pod

=head1 NAME

RUM::Script - Common utilities for running other tasks using the shell or qsub

=head1 FUNCTIONS 

=over

=cut

use strict;
no warnings;

use File::Path qw(mkpath);
use Carp;
use Exporter qw(import);

our @EXPORT_OK = qw(is_dry_run shell make_paths with_dry_run 
                    is_on_cluster);


=back

=cut

1;

