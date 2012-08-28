package RUM::Action::Start;

use strict;
use warnings;
use autodie;

use base 'RUM::Action';

use RUM::Logging;

our $log = RUM::Logging->get_logger;

RUM::Lock->register_sigint_handler;

sub new { shift->SUPER::new(name => 'align', @_) }

sub run {
    my ($class) = @_;
    my $self = $class->new;

    # Parse the command line and construct a RUM::Config
    my $c = $self->make_config;

    if ( ! -d $c->in_output_dir('.rum')) {
        die($c->output_dir . " does not appear to be a RUM output directory." .
            " Please use 'rum_runner align' to start a new job");
            
    }
}

sub make_config {

    my ($self) = @_;

    my $usage = RUM::Usage->new('action' => 'align');

    my $config = RUM::Config->new->from_command_line;

    if ($config->{chunks}) {
        die("You can't change the number of chunks on a job that has already " .
            "been set up. If you need to change the number of chunks, please " .
            "use 'rum_runner align' to start a new job from scratch.");
        
    }

    if (@ARGV) {
        die("Unrecognized arguments @ARGV");
    }


    if ($config->lock_file) {
        $log->info("Got lock_file argument (" .
                   $config->lock_file . ")");
        $RUM::Lock::FILE = $config->lock_file;
    }


    $usage->check;
    return $self->{config} = $config;
}
1;
