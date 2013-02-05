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

    $self->pipeline->stop;
    $self->pipeline->clean(1);

    $self->say("RUM job in " . $self->config->output_dir . " has been killed.");
}

sub pod_header {

return <<'EOF';

=head1 NAME

rum_runner kill - Clean up files for a job

=head1 SYNOPSIS

rum_runner kill -o dir

=head1 DESCRIPTION

Kill a RUM job running on a cluster: stop it from running and remove
all the associated output files. This will allow you to start the job
over again from the beginning, with different parameters if necessary.

If you just want to stop the job, but leave all the output files so
you can resume it from where it left off, please use C<rum_runner
stop> instead.

EOF
}

1;


