package RUM::Cluster::SGE;

use strict;
use warnings;

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

    return bless $self, $class;
}

sub config {
    $_[0]->{config};
}

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
    $self->{preproc_jid} = $self->qsub("sh", $sh);
}

sub submit_proc {
    my ($self, $c) = @_;
    my $sh = $self->_write_shell_script("proc");
    my $n = $self->config->num_chunks;
    my @args = ("-t", "1:$n");
    if (my $prereq = $self->{preproc_jid}) {
        push @args, "-hold_jid", $prereq;
    }
    $self->{proc_jid} = $self->qsub(@args, "sh", $sh);
}

sub submit_postproc {
    my ($self, $c) = @_;
    my $sh = $self->_write_shell_script("postproc");
    my @args;
    if (my $prereq = $self->{proc_jid}) {
        push @args, "-hold_jid", $prereq;
    }
    $self->{postproc_jid} = $self->qsub(@args, "sh", $sh);
}

sub parse_qsub_out {
    my $self = shift;
    local $_ = shift;
    /Your.* job(-array)? (\d+)/ and return $2;
}

sub qsub {
    my ($self, @args) = @_;
    my $cmd = "qsub -V -cwd -j y -b y @args";
    $log->info("Running $cmd");
    my $out = `$cmd`;

    if ($?) {
        croak "Error running qsub @args: $!";
    }

    return $self->parse_qsub_out($out);
}

sub qstat {
    
}

1;
