package RUM::Script::Base;

use strict;
use warnings;

use Scalar::Util qw(blessed);

use Getopt::Long;

sub logger {
    my ($self) = @_;
    my $package = blessed($self);
    return $self->{logger} ||= RUM::Logging->get_logger($package);
}

sub get_options {
    my ($self, %options) = @_;

    $options{'q|quiet'}   = sub { $self->logger->less_logging };
    $options{'q|verbose'} = sub { $self->logger->more_logging };
    $options{'h|help'}    = sub { RUM::Usage->help };
    GetOptions(%options);
}

sub option {
    my ($self, $name) = @_;

    return $self->{options}->{$name};
}

1;
