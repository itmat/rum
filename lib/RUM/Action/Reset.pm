package RUM::Action::Reset;

use strict;
use warnings;

use RUM::Action::Kill;
use RUM::Action::Clean;

use base 'RUM::Action';

sub run {
    my ($class) = @_;

    my $self = $class->new(name => 'kill');
    $self->get_options;
    $self->check_usage;

    if ( ! $self->{loaded_config} ) {
        $self->say("There does not appear to be a RUM job in "
                   . $self->config->output_dir);
        return;
    }

    my $kill_action  = RUM::Action::Kill->new(config => $self->config);
    my $clean_action = RUM::Action::Clean->new(config => $self->config);

    $kill_action->do_kill;
    $clean_action->clean(1);
}

1;

__END__

=head1 NAME

RUM::Action::Reset - Kill a rum job and remove all of its output

=head1 DESCRIPTION

Kills a job if it's running, and removes all of its output files.

=over 4

=item run

Reset the job.

=cut

=back
