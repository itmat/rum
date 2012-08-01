package RUM::Action::Stop;

use strict;
use warnings;

use base 'RUM::Action';

sub new { shift->SUPER::new(name => 'stop', @_) }

sub run {
    my ($class) = @_;

    my $self = $class->new;
    $self->get_options;
    $self->check_usage;
    $self->do_stop;
}

sub do_stop {
    my ($self) = @_;
    $self->platform->stop;
}

1;

__END__

=head1 NAME

RUM::Action::Stop - Stop a rum job

=head1 DESCRIPTION

Stops a running rum job.

=over 4

=item run

Stop the job.

=cut

=back
