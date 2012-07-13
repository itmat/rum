package RUM::Script::Base;

use strict;
use warnings;

use Scalar::Util qw(blessed);

sub logger {
    my ($self) = @_;
    my $package = blessed($self);
    return $self->{logger} ||= RUM::Logging->get_logger($package);
}

sub options {
    
}

1;
