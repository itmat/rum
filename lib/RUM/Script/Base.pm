package RUM::Script::Base;

use strict;
use warnings;

sub logger {
    my ($self) = @_;
    return $self->{logger} ||= RUM::Logging->get_logger;
}

1;
