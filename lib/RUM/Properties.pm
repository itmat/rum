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
        confess "Property $key is not allowed";
    }
    $self->{properties}{$key} = $value;
}

sub get {
    my ($self, $key) = @_;
    if (!$self->{allowed}{$key}) {
        confess "Property $key is not allowed";
    }
    return $self->{properties}{$key};
}

sub has {
    my ($self, $key) = @_;
    if (!$self->{allowed}{$key}) {
        confess "Property $key is not allowed";
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

=head1 NAME

RUM::Properties - Group of properties parsed from command line

=over 4

=item RUM::Properties->new($allowed)

Create a new group of properties, with the given list of allowed names.

=item $props->set($name, $value)

Set the $name to $value. Will die if $name was not included in the list of allowed names in the constructor.

=item $props->get($name)

Return the value that $name is set to, or die if $name is not allowed.

=item $props->has($name)

Return true if the given name was set.

=item $props->errors

Return the RUM::UsageErrors object for this group of properties.

=item $props->names

Return the list of names set for this proeprty group.

=back
