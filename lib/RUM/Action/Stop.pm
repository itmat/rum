package RUM::Action::Stop;

use strict;
use warnings;

use base 'RUM::Action';

use RUM::Pipeline;

sub new { shift->SUPER::new(name => 'stop', @_) }

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
}

1;

__END__

=head1 NAME

RUM::Action::Stop - Stop a rum job

=head1 CONSTRUCTORS

=over 4

=item RUM::Action::Stop->new

=back

=head1 DESCRIPTION

Stops a running rum job.

=over 4

=item run

Stop the job.

=item accepted_options

Returns the map of options accepted by this action.

=cut

=back
