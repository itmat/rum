package RUM::Action::Reset;

use strict;
use warnings;

use Carp;


use RUM::Pipeline;

use base 'RUM::Action';

sub new { shift->SUPER::new(name => 'reset', @_) }

sub accepted_options {
    return (
        options => [qw(output_dir step)],
        load_default => 1);
}

sub run {
    my ($class) = @_;
    my $self = $class->new;

    $self->pipeline->reset_job;
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
