package RUM::Properties;

use strict;
use warnings;

use Carp;

use RUM::UsageErrors;

sub new {
    my ($class, $allowed) = @_;
    my $self = bless {
        properties => {},
        errors => RUM::UsageErrors->new,
        allowed => {},
    }, $class;

    for my $prop (@{ $allowed } ) {
        $self->{allowed}->{$prop->name} = 1;
    }

    return $self;
}

sub set {
    my ($self, $key, $value) = @_;
    if (!$self->{allowed}{$key}) {
        croak "Property $key is not allowed";
    }
    $self->{properties}{$key} = $value;
}

sub get {
    my ($self, $key) = @_;
    if (!$self->{allowed}{$key}) {
        croak "Property $key is not allowed";
    }
    return $self->{properties}{$key};
}

sub has {
    my ($self, $key) = @_;
    if (!$self->{allowed}{$key}) {
        croak "Property $key is not allowed";
    }
    return defined $self->{properties}{$key};
}

sub errors {
    shift->{errors};
}

sub names {
    keys %{ shift->{properties} }
}

1;
