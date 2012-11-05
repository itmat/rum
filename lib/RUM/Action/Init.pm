package RUM::Action::Init;

use strict;
use warnings;
use autodie;

use base 'RUM::Action';

our $log = RUM::Logging->get_logger;

RUM::Lock->register_sigint_handler;

sub load_default { }

sub accepted_options {
    my @names = RUM::Config->job_setting_props;
    push @names, 'chunks', 'output_dir';
    my %props = map { ($_ => RUM::Config->property($_)) } @names;
    $props{index_dir}->set_required;
    $props{name}->set_required;
    $props{chunks}->set_required;
    $props{output_dir}->set_required;

    my @props = values %props;
    push @props, RUM::Config->property('forward_reads')->set_required;
    push @props, RUM::Config->property('reverse_reads');
    return @props;
}

sub run {
    my ($self) = @_;
    $self->show_logo;
    $self->pipeline->initialize;
}

sub summary {
    "Initialize a RUM job but don't start it"
}

sub description {
    my $pod = << "EOF";

Initializes a RUM job, without actually running it.

When you run C<rum_runner init -o I<dir> OPTIONS> on output directory
I<dir>, rum_runner will save the options you ran it with in
I<dir/.rum/job_settings>. You can then run the job using C<rum_runner start> or C<rum_runner restart>

Note: You can use C<rum_runner align> to initialize and run a job at
the same time.

EOF
    return $pod;
}
