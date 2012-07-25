package RUM::BlatAlignment;

use strict;
use warnings;

use base 'RUM::Alignment';

sub new {
    my ($class, %params) = @_;

    my $self = $class->SUPER::new(%params);
    for my $key (qw()) {
        $self->{$key} = $params{$key};
    }

    return $self;
}

1;
