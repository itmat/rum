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

sub pod_header {
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

=head1 DESCRIPTION

Initializes a RUM job, without actually running it.

When you run C<rum_runner init -o I<dir> OPTIONS> on output directory
I<dir>, rum_runner will save the options you ran it with in
I<dir/.rum/job_settings>. You can then run the job using C<rum_runner start> or C<rum_runner restart>

Note: You can use C<rum_runner align> to initialize and run a job at
the same time.

EOF
    return $pod;
}



