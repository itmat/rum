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

    my $config = RUM::Config->new->parse_command_line(
        $self->accepted_options);
    my $pipeline = RUM::Pipeline->new($config);

    $pipeline->print_status;
}

1;
