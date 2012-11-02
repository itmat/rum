package RUM::Action::Stop;

use strict;
use warnings;

use base 'RUM::Action';

sub load_default { 1 }

sub summary { 'Stop a rum job' }

sub accepted_options {
    return (
        RUM::Config->property('output_dir')->set_required
    );
}

sub run {
    my ($self) = @_;
    $self->pipeline->stop;
}

1;

