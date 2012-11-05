package RUM::Action::Clean;

use strict;
use warnings;
use Carp;
use RUM::Pipeline;

use base 'RUM::Action';

sub accepted_options {
    my ($class) = @_;
    return (
        RUM::Config->property('output_dir')->set_required
      );
}

sub load_default { 1 }

sub run {
    my ($self) = @_;
    $self->pipeline->clean;
}

sub summary {
    'Clean up files for a job'
}

sub description {

    return <<'EOF';
Clean up the intermediate and temporary files produced for a
job. Optionally clean up the final result files as well.

If you run C<rum_runner align> without the --no-clean option, it
should automatically delete the intermediate and temporary files as it
goes, but if it crashes or is killed it may leave some junk around.

EOF

}

1;


