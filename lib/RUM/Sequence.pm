package RUM::Sequence;

use strict;
use warnings;
use autodie;

use Carp;

use base 'RUM::Identifiable';

sub new {
    my ($class, %params) = @_;
    my $self = $class->SUPER::new(%params);
    $self->{seq} = delete $params{seq} or croak "Need seq";
    return $self;
}

sub seq { $_[0]->{seq} }

1;
