package RUM::Action::Start;

use strict;
use warnings;
use autodie;

use base 'RUM::Action';


use RUM::Logging;
use RUM::Action::Clean;
use RUM::Action::Reset;

our $log = RUM::Logging->get_logger;

RUM::Lock->register_sigint_handler;

sub new { shift->SUPER::new(name => 'align', @_) }

sub run {
    my ($class) = @_;
    my $self = $class->new;
    my $config = $self->make_config;
    my $pipeline = RUM::Pipeline->new($config);
    $pipeline->start;
}

sub make_config {

    my ($self) = @_;

    my $config = RUM::Config->new->parse_command_line(
        options => [RUM::Config->job_setting_props,
                    RUM::Config->step_props,
                    RUM::Config->common_props,
                    'no_clean', 'output_dir'],
        load_default => 1);

    my $pipeline = RUM::Pipeline->new($config);

    $pipeline->reset_if_needed;

    if ($config->lock_file) {
        $log->info("Got lock_file argument (" .
                   $config->lock_file . ")");
        $RUM::Lock::FILE = $config->lock_file;
    }

    return $config;
}


1;
