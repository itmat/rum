package RUM::Action::Kill;

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

    $self->pipeline->stop;
    $self->pipeline->clean(1);

    print "RUM job in " . $self->config->output_dir . " has been killed.";
}

sub summary {
    'Clean up files for a job'
}

sub description {

return <<'EOF';

=head1 DESCRIPTION

Kill a RUM job running on a cluster: stop it from running and remove
all the associated output files. This will allow you to start the job
over again from the beginning, with different parameters if necessary.

If you just want to stop the job, but leave all the output files so
you can restart it from where it left off, please use C<rum_runner
stop> instead.

EOF
}

1;


