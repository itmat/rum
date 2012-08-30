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

sub accepted_options {
    return (        
        options => [RUM::Config->common_props,
                    RUM::Config->job_setting_props,
                    'output_dir'],
        positional => ['forward_reads', 'reverse_reads']);
}

sub run {
    my ($class) = @_;
    my $self = $class->new;

    # Parse the command line and construct a RUM::Config
    my $config = RUM::Config->new->parse_command_line(
        $self->accepted_options);

    my $pipeline = RUM::Pipeline->new($config);

    $pipeline->initialize;
}

sub pod {
    my ($class) = @_;
    my $pod = << "EOF";

=head1 NAME

rum_runner init - Initialize a RUM job but don't start it

=head1 SYNOPSIS

  # Start a job
  rum_runner init
      --index-dir INDEX_DIR  
      --name      JOB_NAME   
      --output    OUTPUT_DIR 
      --chunks    NUM_CHUNKS
      FORWARD_READS [ REVERSE_READS ]
      [ OPTIONS ]

=head1 OPTIONS

=over 4

EOF

    my %options = $class->accepted_options;

    for my $option (sort @{ $options{options} || []}) {
        $pod .= RUM::Config->pod_for_prop($option);
    }

    return $pod;
}

