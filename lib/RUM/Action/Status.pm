package RUM::Action::Status;

use strict;
use warnings;

use base 'RUM::Action';

sub load_default { 1 }

sub accepted_options {
    return (
        RUM::Config->property('output_dir')->set_required
    );
}

sub run {
    my ($self) = @_;
    $self->pipeline->print_status;
}

sub summary { 'Show the status of a job' }

1;
