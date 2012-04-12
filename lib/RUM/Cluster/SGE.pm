package RUM::Cluster::SGE;

use strict;
use warnings;

use RUM::Logging;

use Carp;

our $log = RUM::Logging->get_logger();

sub new {
    my ($class, $config) = @_;
    my $self = {};
    $self->{config} = $config;

    my $dir = $config->output_dir;

    $self->{cmd} = {};
    $self->{cmd}{preproc}  =  "perl $0 --child --output $dir --preprocess";
    $self->{cmd}{proc}     =  "perl $0 --child --output $dir --chunk \$SGE_TASK_ID";
    $self->{cmd}{postproc} =  "perl $0 --child --output $dir --postprocess";

    $self->{jids}{preproc} = [];
    $self->{jids}{proc} = [];
    $self->{jids}{postproc} = [];

    return bless $self, $class;
}

sub config {
    $_[0]->{config};
}

sub preproc_jids  { $_[0]->{jids}{preproc} };
sub proc_jids     { $_[0]->{jids}{proc} };
sub postproc_jids { $_[0]->{jids}{postproc} };

sub _write_shell_script {
    my ($self, $phase) = @_;
    my $filename = $self->config->in_output_dir(
        $self->config->name . "_$phase" . ".sh");
    open my $out, ">", $filename or croak "Can't open $filename for writing: $!";
    my $cmd = $self->{cmd}{$phase} or croak "Don't have command for phase $phase";

    print $out 'RUM_CHUNK=$SGE_TASK_ID\n';
    print $out $self->{cmd}{$phase};
    close $out;
    return $filename;
}

sub submit_preproc {
    my ($self) = @_;
    $log->info("Submitting preprocessing job");
    my $sh = $self->_write_shell_script("preproc");
    my $jid = $self->qsub("sh", $sh);
    push @{ $self->preproc_jid }, $jid;
}

sub submit_proc {
    my ($self, $c) = @_;
    my $sh = $self->_write_shell_script("proc");
    my $n = $self->config->num_chunks;
    my @args = ("-t", "1:$n");
    my @prereqs = @{ $self->preproc_jids };
    push @args, "-hold_jid", join(",", @prereqs) if @prereqs;
    my $jid = $self->qsub(@args, "sh", $sh);
    push @{ self->proc_jids }, $jid;
}

sub submit_postproc {
    my ($self, $c) = @_;
    my $sh = $self->_write_shell_script("postproc");
    my @args;
    my @prereqs = $self->proc_jids;
    push @args, "-hold_jid", join(",", @prereqs) if @prereqs;
    push @{ $self->postproc_jids }, $self->qsub(@args, "sh", $sh);
}

sub parse_qsub_out {
    my $self = shift;
    local $_ = shift;
    /Your.* job(-array)? (\d+)/ and return $2;
}

sub qsub {
    my ($self, @args) = @_;
    my $cmd = "qsub -V -cwd -j y -b y @args";
    $log->debug("Running '$cmd'");
    my $out = `$cmd`;
    $log->debug("'$cmd' produced output $out");
    if ($?) {
        croak "Error running qsub @args: $!";
    }

    return $self->parse_qsub_out($out);
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

sub parse_qstat_out {
    (my $self, local $_) = @_;

    my ($job_start,   $job_len)   = _field_start_len("job-ID");
    my ($state_start, $state_len) = _field_start_len("state");
    my ($task_start,  $task_len)  = _field_start_len("ja-task-ID");

    my @result;

    my @lines = split /\n/;

    for my $line (@lines[2..$#lines]) {
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

sub update_status {
    my ($self) = @_;

    my $qstat = `qstat`;
    if ($?) {
        croak "qstat command failed: $!";
    }
    $log->debug("Qstat output was\n$qstat");

    $self->_build_job_states($self->parse_qstat_out($qstat));
}

sub _build_job_states {
    my ($self, $jobs) = @_;
    my $jid_map = $self->{jids};

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
    my @ok = grep { $_ && /r|w/ } @states;
    
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

sub preproc_ok {
    my ($self) = @_;
    return $self->_some_job_ok("preproc", $self->preproc_jids);
}

sub proc_ok {
    my ($self, $chunk) = @_;
    return $self->_some_job_ok("proc", $self->proc_jids, $chunk);
}

sub postproc_ok {
    my ($self) = @_;
    return $self->_some_job_ok("postproc", $self->postproc_jids);
}

1;
