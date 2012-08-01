package RUM::Action::Kill;

use strict;
use warnings;

use base 'RUM::Action';

sub run {
    my ($class) = @_;

    my $self = $class->new(name => 'kill');
    $self->get_options;
    $self->check_usage;
    $self->do_kill;
}

sub do_kill {
    my ($self) = @_;
    $self->say("Stopping job");
    $self->platform->stop;
}

1;

__END__

=head1 NAME

RUM::Action::Kill - Kill a rum job

=head1 DESCRIPTION

Kills a running rum job.

=over 4

=item run

Kill the job.

=cut

=back
