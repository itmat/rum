package RUM::Base;

=head1 NAME

RUM::Base - Base class for a few RUM classes

=head1 SYNOPSIS

  use base 'RUM::Base';

  ...

  my $config = $self->config;
  my $directives = $self->directives;
  my @reads = $self->reads;
  $self->say("Message to user");
  my @chunks = $self->chunk_nums;

=head1 DESCRIPTION

Provides a few methods that are commonly used by RUM::Runner and
RUM::Platform and its subclasses; basically any class that needs
access to the RUM::Config for the job and the RUM::Directives for this
invocation of rum_runner.

=cut

use strict;
use warnings;

use Carp;

use Text::Wrap qw(wrap fill);

=head1 CONSTRUCTOR

=over 4

=item new($config, $directives)

Subclasses that defined a I<new> method should call me in the
constructor before doing anything else.

=back

=cut

sub new {
    my ($class, $config, $directives) = @_;
    my $self = {};
    $self->{config} = $config or croak
        "$class->new called without config";
    $self->{directives} = $directives or croak
        "$class->new called without directives";
    bless $self, $class;
}

=head1 METHODS

=over 4

=cut


=item config

Return the config for this RUM job.

=cut

sub config { $_[0]->{config} }

=item directives

Return the RUM::Directives for this invocation of
RUM::Runner. Directives are boolean flags that the user provides to
RUM::Runner to tell it what to do.

=cut

sub directives { $_[0]->{directives} }

=item say(@msg)

Print a message to the user, wrapping long lines.

=cut

sub say {
    my ($self, @msg) = @_;
    #$log->info("@msg");
    print wrap("", "", @msg) . "\n" unless $self->directives->quiet;
}

=item chunk_nums

Return a list of chunk numbers I'm supposed to process, which is a
single number if I was run with a --chunk option, or all of the chunks
from 1 to $n otherwise.

=cut

sub chunk_nums {
    my ($self) = @_;
    my $c = $self->config;
    if ($c->chunk) {
        return ($c->chunk);
    }
    return (1 .. $c->num_chunks || 1)
}

=back

=cut

1;
