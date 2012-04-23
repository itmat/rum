package RUM::Platform::SGE;

=head1 NAME

RUM::Platform::SGE - Run the rum pipeline on the Sun Grid Engine.

=head1 DESCRIPTION

Provides methods for submitting phases of the rum pipeline to the Sun
Grid Engine, and checking on their status.

=cut

use strict;
use warnings;

use Carp;
use Data::Dumper;

use RUM::Logging;
use RUM::Common qw(shell);
use base 'RUM::Platform::Cluster';

our $log = RUM::Logging->get_logger();


our $JOB_ID_FILE = ".rum/sge_job_ids";
our @JOB_TYPES = qw(parent preproc proc postproc);
our %JOB_TYPE_NAMES = (
    parent => "parent",
    preproc => "preprocessing",
    proc => "processing",
    postproc => "postprocessing"
);


=head1 CONSTRUCTORS

=over 4

=item new

Construct a RUM::Cluster::SGE with the given configuration and
directives. Loads the state of the jobs from .rum/sge_job_ids in the
output directory, if such a file exists.

=back

=cut

sub new {
    my ($class, $config, $directives) = @_;

    local $_;

    my $self = $class->SUPER::new($config, $directives);
    
    my $dir = $config->output_dir;

    $self->{cmd} = {};
    $self->{cmd}{preproc}  =  "perl $0 align --child --output $dir --preprocess";
    $self->{cmd}{proc}     =  "perl $0 align --child --output $dir --chunk \$SGE_TASK_ID";
    $self->{cmd}{postproc} =  "perl $0 align --child --output $dir --postprocess";

    $self->{jids}{$_} = [] for @JOB_TYPES;

    my $filename = $config->in_output_dir($JOB_ID_FILE);
    if (-e $filename) {
        $self->{jids} = do $filename;
    }
    return bless $self, $class;
}

=head1 METHODS

=over 4

=cut

=item start_parent

Submits a job to run rum_runner on this output directory with the
--parent option. This way, when the user runs rum_runner with --qsub
or --platform SGE, that process calls start_parent and then exits
quickly. When rum_runner is called with --parent, it monitors the
status of the other tasks it submits.

Updates $JOB_ID_FILE so that we keep track of which jobs we've
submitted.

=cut

sub start_parent {
    my ($self) = @_;
    my $d = $self->directives;
    my $dir = $self->config->output_dir;
    my $cmd =  "-b y $0 align --parent --output $dir --lock $RUM::Lock::FILE";
    $cmd .= " --preprocess"  if $d->preprocess;
    $cmd .= " --process"     if $d->process;
    $cmd .= " --postprocess" if $d->postprocess;
    my $jid = $self->_qsub($cmd);
    push @{ $self->_parent_jids }, $jid;
    $self->save;
}

=item ram_args

Return a list of ram-related arguments to pass to qsub.

=cut

sub ram_args {
    my ($self) = @_;
    my $ram = $self->config->min_ram_gb . "G";
    ("-l", "mem_free=$ram,h_vmem=$ram");
}

=item submit_preproc

Submits the preprocessing task, adds the job ids to my state, and
updates $JOB_ID_FILE.

=cut

sub submit_preproc {
    my ($self) = @_;
    $log->info("Submitting preprocessing job");
    my $sh = $self->_write_shell_script("preproc");
    my $jid = $self->_qsub($sh);
    push @{ $self->_preproc_jids }, $jid;
    $self->save;
}

=item submit_proc

Submits an array job to run all of the chunks, adds the job id to my
state, and updates $JOB_ID_FILE. The array job depends on the
preprocessing job, if I have the job id of a preprocessing job on
record.

=cut

sub submit_proc {
    my ($self, @chunks) = @_;
    my $sh = $self->_write_shell_script("proc");
    my $n = $self->config->num_chunks;

    my @prereqs = @{ $self->_preproc_jids };

    my @args = $self->ram_args;
    my @jids;

    if (@prereqs) {
        $log->info("Submitting processing job; waiting for preprocessing (@prereqs) to finish");
        push @args, "-hold_jid", join(",", @prereqs) if @prereqs;
    }
    else {
        $log->info("Submitting processing jobs");
    }

    if (@chunks) {
        for my $chunk (@chunks) {
            push @jids, $self->_qsub(@args, "-t", $chunk, $sh);
        }
    }
    else {
        push @jids, $self->_qsub(@args, "-t", "1:$n", $sh);
    }

    push @{ $self->_proc_jids }, @jids;
    $self->save;
}

=item submit_postproc

Submits a job for the postprocessing phase and updates
$JOB_ID_FILE. Note that this does not add a dependency on the array
job for the processing phase, since we may restart one or more of
those array tasks if they fail. The caller must not call
submit_postproc until the processing is done.

=cut

sub submit_postproc {
    my ($self, $c) = @_;
    $log->info("Submitting postprocessing job");
    my $sh = $self->_write_shell_script("postproc");
    my $jid = $self->_qsub($self->ram_args, $sh);
    push @{ $self->_postproc_jids }, $jid;
    $self->save;
}

=item update_status

Run qstat and parse the results, updating my internal model of the
status of all jobs.

=cut

sub update_status {
    my ($self) = @_;

    my @qstat = `qstat`;
    if ($?) {
        croak "qstat command failed: $!";
    }
    $log->debug("qstat: $_") foreach @qstat;

    $self->_build_job_states($self->_parse_qstat_out(@qstat));
    $self->save;
}

=item preproc_ok

=item proc_ok

=item postproc_ok

These methods return true if the preproc, proc, or postproc phase is
in an 'ok' status, meaning that it is running or at least in the queue
in a state that indicates it can be run in the future.

=cut

sub preproc_ok {
    my ($self) = @_;
    return $self->_some_job_ok("preproc", $self->_preproc_jids);
}

sub proc_ok {
    my ($self, $chunk) = @_;
    $chunk or croak "$self->proc_ok() called without chunk";
    return $self->_some_job_ok("proc", $self->_proc_jids, $chunk);
}

sub postproc_ok {
    my ($self) = @_;
    return $self->_some_job_ok("postproc", $self->_postproc_jids);
}

=item save

Save the job ids to the $JOB_IDS_FILE.

=cut

sub save {
    my ($self) = @_;
    open my $out, ">", $self->config->in_output_dir($JOB_ID_FILE);
    print $out Dumper($self->{jids});
}


################################################################################
###
### Private methods
###

sub _parse_qsub_out {
    my $self = shift;
    local $_ = shift;
    /Your.* job(-array)? (\d+)/ and return $2;
}

sub _qsub {
    my ($self, @args) = @_;
    my $dir = $self->config->output_dir;
    my $cmd = "qsub -V -cwd -j y -o $dir -e $dir @args";
    $log->debug("Running '$cmd'");
    my $out = `$cmd`;
    $log->debug("'$cmd' produced output $out");
    if ($?) {
        croak "Error running qsub @args: $!";
    }

    return $self->_parse_qsub_out($out);
}

sub _field_start_len {
    my ($field) = @_;
    /(.*)($field\s*)/ or croak "Can't find field $field in qstat output:\n$_\n";
    return (length($1), length($2))
}

sub _extract_field {
    my ($line, $off, $len) = @_;
    return unless $off < length($line);
    my $text = substr $line, $off, $len;
    $text =~ s/^\s*//;
    $text =~ s/\s*$//;
    return $text if $text;
}

sub _parse_qstat_out {
    my ($self, @lines) = @_;

    # Get the header line and determine the offset and length of each
    # field from it
    local $_ = shift @lines;
    my ($job_start,   $job_len)   = _field_start_len("job-ID");
    my ($state_start, $state_len) = _field_start_len("state");
    my ($task_start,  $task_len)  = _field_start_len("ja-task-ID");

    # Shift of the dash line
    shift @lines;

    my @result;

    for my $line (@lines) {
        my $job   = _extract_field $line, $job_start, $job_len or croak
            "Got empty job id from line $line";
        my $state   = _extract_field $line, $state_start, $state_len or croak
            "Got empty state from line $line";
        my $task   = _extract_field $line, $task_start, $task_len;

        my %rec = (job_id => $job, state => $state);

        if ($task && $task =~ /(\d+)-(\d+):(\d+)/) {
            my ($first, $last) = ($1, $2);

            for my $task_id ($first .. $last) {
                push @result, { %rec, task_id => $task_id };
            }
        }
        elsif ($task) {
            push @result, { %rec, task_id => $task };
        }
        else {
            push @result, { %rec };
        }
    }
    return \@result;
}

sub _build_job_states {
    my ($self, $jobs) = @_;

    # For preproc and postproc, %states maps a job id to the state of
    # that job according to qstat. For proc, %states maps a job id to
    # an array ref where each slot holds the status for that task of
    # the array job.
    my %states;
    for my $job (@{ $jobs }) {
        my ($jid, $state, $task_id) = @$job{'job_id', 'state', 'task_id'};

        if ($task_id) {
            $states{$jid} ||= [];
            $states{$jid}[$task_id] = $state;
        }
        else {
            $states{$jid} = $state;
        }
    }
    $self->{job_states} = \%states;
    my @jids = keys %states;

    # Some of the jids I used to know about might have
    # disappeared. Remove from my jids map any jids that no longer
    # appear in qstat.
    for my $phase (@JOB_TYPES) {
        my @jids = @{ $self->{jids}{$phase} };
        my @active = grep { $states{$_} } @jids;
        $self->{jids}{$phase}  = \@active;
    }
}

sub _job_state {
    my ($self, $jid, $chunk) = @_;
    
    my $state = $self->{job_states}{$jid} or return undef;
    
    if (defined $chunk) {
        ref($state) =~ /^ARRAY/ or croak 
            "Corrupt job state, should be array ref, was $state";
        return $state->[$chunk];
    }

    return $state;
}

sub _some_job_ok {
    my ($self, $phase, $jids, $task) = @_;
    my @jids = @{ $jids };
    my @states = map { $self->_job_state($_, $task) || "" } @jids;
    my @ok = grep { $_ && /r|w|t/ } @states;
    
    my $msg = "I have these jobs for phase $phase";
    $msg .= " task $task" if $task;
    $msg .= ": [";
    $msg .= join(", ", map "$jids[$_]($states[$_])", (0 .. $#jids)) . "]";

    if (@ok == 1) {
        $log->debug($msg);
        return 1;
    }
    if (@ok == 0) {
        $log->error("$msg and none of them are running or waiting");
    }
    else {
        $log->error("$msg and more than one of them are running or waiting");
    }

    return 0;
}



=item stop

Delete all jobs associated with this output directory.

=cut

sub stop {
    my ($self) = @_;
    $self->update_status;

    my @table = (
        ["parent",         $self->_parent_jids ],
        ["preprocessing",  $self->_preproc_jids ],
        ["processing",     $self->_proc_jids ],
        ["postprocessing", $self->_postproc_jids ]
    );

    for my $type (@JOB_TYPES) {
        my $name = $JOB_TYPE_NAMES{$type};
        my @jids = @{ $self->{jids}{$type} };

        if (@jids) {
            $self->say("Deleting $name job ids @jids");
            system("qdel @jids");
            if ($?) {
                warn "Couldn't delete jobs: " . ($? >> 8);
            }
        }
        else {
            $self->say("Don't seem to have any $name job ids running");
        }
    }
}

# These methods return the SGE job ids for the jobs that are currently
# running to perform the preprocessing, processing, and postprocessing
# phases.

sub _parent_jids   { $_[0]->{jids}{parent} };
sub _preproc_jids  { $_[0]->{jids}{preproc} };
sub _proc_jids     { $_[0]->{jids}{proc} };
sub _postproc_jids { $_[0]->{jids}{postproc} };

sub _write_shell_script {
    my ($self, $phase) = @_;
    my $filename = $self->config->in_output_dir(
        $self->config->name . "_$phase" . ".sh");
    open my $out, ">", $filename or croak "Can't open $filename for writing: $!";
    my $cmd = $self->{cmd}{$phase} or croak "Don't have command for phase $phase";

    print $out 'RUM_CHUNK=$SGE_TASK_ID' . "\n";
    print $out 'RUM_OUTPUT_DIR=' . $self->config->output_dir . "\n";

    print $out $self->{cmd}{$phase};
    close $out;
    return $filename;
}

1;
