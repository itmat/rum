package RUM::Platform;

=head1 NAME

RUM::Platform - Base class for platforms that run the pipeline

=head1 SYNOPSIS

  my $platform = RUM::Platform->get($config, $directives);

  $platform->preprocess;

  $platform->process;

  $platform->postprocess;

=head1 DESCRIPTION

Provides an abstraction over platforms that can be used to run RUM
pipeline.  Separates the workflow into three phases: I<preprocess>,
I<process>, and I<postprocess>.

=head1 CLASS METHODS

=over 4

=item get($config, $directives)

Call me with a RUM::Config and a RUM::Directives, and I'll return a
suitable RUM::Platform for running the workflows for the job.

=back

=head1 OBJECT METHODS

=over 4

=item preprocess

=item process

=item postprocess

Subclasses must implement these three methods to execute the
respective phases of the pipeline.

=back

=cut

use strict;
use warnings;

use Carp;

use base 'RUM::Base';

sub preprocess { croak "Not implemented" }
sub process { croak "Not implemented" }
sub postprocess { croak "Not implemented" }

1;
