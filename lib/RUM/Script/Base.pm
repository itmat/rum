package RUM::Script::Base;

use strict;
use warnings;

use Data::Dumper;
use Scalar::Util qw(blessed);

use Getopt::Long;

sub new {
    my ($class, %self) = @_;
    return bless \%self, $class;
}

sub logger {
    my ($self) = @_;
    my $package = blessed($self);
    return $self->{logger} ||= RUM::Logging->get_logger($package);
}

sub get_options {
    my ($self, %options) = @_;

    $options{  'quiet|q'} = sub { $self->logger->less_logging(1) };
    $options{'verbose|v'} = sub { $self->logger->more_logging(1) };
    $options{   'help|h'} = sub { RUM::Usage->help };
    GetOptions(%options);
}

sub option {
    my ($self, $name) = @_;

    return $self->{options}->{$name};
}

1;
