package RUM::Properties;

use strict;
use warnings;

use Carp;

use RUM::UsageErrors;

sub new {
    my ($class) = @_;
    return bless {
        properties => {},
        errors => RUM::UsageErrors->new
    }, $class;
}

sub set {
    my ($self, $key, $value) = @_;
    $self->{properties}{$key} = $value;
}

sub get {
    my ($self, $key) = @_;
    return $self->{properties}{$key};
}

sub has {
    my ($self, $key) = @_;
    return defined $self->{properties}{$key};
}

sub errors {
    shift->{errors};
}

1;
