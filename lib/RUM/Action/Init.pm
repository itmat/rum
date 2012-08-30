package RUM::Action::Init;

use strict;
use warnings;
use autodie;

use base 'RUM::Action';

use RUM::Logging;
use RUM::SystemCheck;
use RUM::Pipeline;

our $log = RUM::Logging->get_logger;

RUM::Lock->register_sigint_handler;

sub new { shift->SUPER::new(name => 'init', @_) }

sub run {
    my ($class) = @_;
    my $self = $class->new;

    # Parse the command line and construct a RUM::Config
    my $config = RUM::Config->new->parse_command_line(
        options => [RUM::Config->common_props,
                    RUM::Config->job_setting_props,
                    'output_dir'],
        positional => ['forward_reads', 'reverse_reads']);

    my $pipeline = RUM::Pipeline->new($config);

    $pipeline->initialize;
}

