package RUM::Action::Resume;

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

sub accepted_options {
    return ( 
        options => [RUM::Config->job_setting_props,
                    RUM::Config->step_props,
                    RUM::Config->common_props,
                    'from_step',
                    'no_clean', 'output_dir', 'lock'],
        load_default => 1);
}

sub run {
    my ($class) = @_;
    my $self = $class->new;
    $self->show_logo;
    my $pipeline = $self->pipeline;
    if (my $lock_file = $self->config->lock_file) {
        $log->info("Got lock_file argument (" .
                   $lock_file . ")");
        $RUM::Lock::FILE = $lock_file;
    }
    if ($self->config->from_step) {
        $pipeline->reset_job;
    }
    else {
        $pipeline->reset_if_needed;
    }
    $pipeline->start;
}

sub pod_header {

    return << 'EOF';

=head1 NAME

rum_runner resume - Resume a job

=head1 SYNOPSIS

  rum_runner resume
      --output-dir OUTPUT_DIR
      [ --from-step STEP ]
      [ OPTIONS ]

=head1 DESCRIPTION

Runs a job that has already been initialized or partially run. Use
this if you have a job that crashed or that you had to stop for some
reason.

If you do not specify any job settings other than B<--output-dir>,
this will attempt to resume the job from where it stopped.

If you specify B<--from-step>, I will try to resume the job from that
step. The step numbers are found in the output of C<rum_runner
status>.

WARNING: If you use B<--from-step>, I may actually have to resume from
a step much earlier in the pipeline than the one you requested. This
is because I delete intermediate result files as soon as I am done
with them, and I may have to recreate the files I need in order to
restart from the step you requested. In general, using B<--from-step>
should be considered dangerous.

If you specify any other job settings, it will start from just after
the preprocessing phase, so it doesn't have to split the files again.

You cannot specify the number of chunks or the forward and reverse
read files, because those parameters require us to split the input
files again. If you need to change those values, please remove the
directory and start a new job.

EOF

}
1;
