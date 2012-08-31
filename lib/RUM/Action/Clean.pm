package RUM::Action::Clean;

use strict;
use warnings;

use RUM::Pipeline;

use base 'RUM::Action';

sub new { shift->SUPER::new(name => 'clean', @_) }

sub accepted_options {
    my ($class) = @_;
    return (
        options => [qw(output_dir)],
        load_default => 1);
}

sub run {
    my ($class) = @_;
    $class->new->pipeline->clean;
}

sub pod_header {

return <<'EOF';

=head1 NAME

rum_runner clean - Clean up files for a job

=head1 SYNOPSIS

rum_runner clean -o dir

=head1 DESCRIPTION

Clean up the intermediate and temporary files produced for a
job. Optionally clean up the final result files as well.

If you run C<rum_runner align> without the --no-clean option, it
should automatically delete the intermediate and temporary files as it
goes, but if it crashes or is killed it may leave some junk around.

EOF
}

1;


