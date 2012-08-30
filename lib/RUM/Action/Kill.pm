package RUM::Action::Kill;

use strict;
use warnings;

use RUM::Action::Stop;
use RUM::Action::Clean;

use base 'RUM::Action';

sub new { shift->SUPER::new(name => 'clean', @_) }

sub accepted_options {
    return (
        options => [qw(output_dir)],
        load_default => 1);
}

sub run {
    my ($class) = @_;

    my $self = $class->new;

    # Parse the command line and construct a RUM::Config
    my $config = RUM::Config->new->parse_command_line(
        $self->accepted_options);

    my $pipeline = RUM::Pipeline->new($config);
    $pipeline->stop;

    $pipeline->clean(1);

    $self->say("RUM job in " . $config->output_dir . " has been killed.");
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
