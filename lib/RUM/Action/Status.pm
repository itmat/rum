package RUM::Action::Status;

use strict;
use warnings;

use base 'RUM::Action';

use RUM::Pipeline;

sub accepted_options {
    return (
        options => [qw(output_dir)],
        load_default => 1);
}

sub run {
    my ($class) = @_;

    my $self = $class->new(name => 'status');
    $self->pipeline->print_status;
}

sub pod_header {

return <<'EOF';

=head1 NAME

rum_runner status - Show the status of a job

=head1 SYNOPSIS

rum_runner status -o dir

=head1 DESCRIPTION

Show the status of any job, based on the output directory.

EOF

}
1;

__END__

=head1 NAME

RUM::Action::Status - Print job status

=head1 OPTIONS

=over 4

=item accepted_options

Return the map of options accepted by this action.

=back
