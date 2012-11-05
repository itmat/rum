package RUM::Action::Resume;

use strict;
use warnings;
use autodie;

use base 'RUM::Action';

our $log = RUM::Logging->get_logger;

RUM::Lock->register_sigint_handler;

sub load_default { 1 }

sub accepted_options {
    my @names = RUM::Config->job_setting_props;
    push @names, 'output_dir', 'from_step', 'no_clean', 'lock';
    push @names, qw(preprocess process postprocess chunk parent child);
    my %props = map { ($_ => RUM::Config->property($_)) } @names;
    $props{output_dir}->set_required;
    delete $props{max_insertions};
    my @props = values %props;
    return @props;
}

sub run {
    my ($self) = @_;
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

sub summary { 'Resume a job' }

sub description {

    return << 'EOF';

Runs a job that has already been initialized or partially run. Use
this if you have a job that crashed or that you had to stop for some
reason.

If you do not specify any job settings other than B<--output-dir>,
this will attempt to restart the job from where it stopped.

If you specify B<--from-step>, I will try to resume the job from that
step. The step numbers are found in the output of C<rum_runner
status>. I may need to restart from an earlier step, if I've already
cleaned up the intermediate output files required by the step you
specify.

If you specify any other job settings, it will start from just after
the preprocessing phase, so it doesn't have to split the files again.

You cannot specify the number of chunks or the forward and reverse
read files, because those parameters require us to split the input
files again. If you need to change those values, please remove the
directory and start a new job.

EOF

}
1;
