package RUM::Action::Kill;

use strict;
use warnings;

use RUM::Action::Stop;
use RUM::Action::Clean;

use base 'RUM::Action';

sub run {
    my ($class) = @_;

    my $self = $class->new(name => 'stop');
    $self->get_options;
    $self->check_usage;

    if ( ! $self->{loaded_config} ) {
        $self->say("There does not appear to be a RUM job in "
                   . $self->config->output_dir);
        return;
    }

    my $stop_action  = RUM::Action::Stop->new(config => $self->config);
    my $clean_action = RUM::Action::Clean->new(config => $self->config);

    $stop_action->do_stop;
    $clean_action->clean(1);
}

1;

__END__

=head1 NAME

RUM::Action::Kill - Stop a rum job and remove all of its output

=head1 DESCRIPTION

Stops a job if it's running, and removes all of its output files.

=over 4

=item run

Kill the job.

=cut

=back
