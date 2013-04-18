package RUM::Platform::Cluster;

use strict;
use warnings;

use Carp;

use RUM::WorkflowRunner;
use RUM::Logging;
use RUM::JobStatus;

use base 'RUM::Platform';

our $log = RUM::Logging->get_logger;

our $CLUSTER_CHECK_INTERVAL = 30;
our $NUM_CHECKS_BEFORE_RESTART = 5;

sub preprocess {
    my ($self) = @_;
    $self->say("Submitting preprocessing task");
    $self->submit_preproc;
}

sub process {
    my ($self, $chunk) = @_;

    if ($chunk) {
        $self->say("Submitting chunk $chunk");
        $self->submit_proc($chunk);
        return;
    }

    # Build a list of tasks, one for each chunk, that bundles together
    # the chunk number, configuration, workflow, and workflow runner.
    # The first task is undef since chunk ids start at 1.

    my @tasks = (undef);
    for my $chunk ($self->chunk_nums) {
        my $workflow = $self->chunk_workflow($chunk);
        my $run = sub { $self->submit_proc($chunk) };
        my $runner = RUM::WorkflowRunner->new($workflow, $run);
        push @tasks, {
            chunk => $chunk,
            workflow => $workflow,
            runner => $runner,
            not_ok_count => 0
        };
    }

    # A slot for each chunk. Set to 0 if a chunk fails. TODO: Maybe set to 1 if
    # it succeeds.
    my @results = (undef);

    # First submit all the chunks as one array job
    $self->submit_proc;

    my $status = RUM::JobStatus->new($self->config);

    # While there are still some chunks that aren't finished
    while ( my @chunks = $status->outstanding_chunks ) {

        $log->info("Chunks still outstanding: @chunks");

        # Get a list of the task maps for the outstanding chunks
        my @tasks = @tasks[@chunks];

        # Refresh the cluster's status so that calls to proc_ok will
        # return the latest status
        $log->info("Updating status (in Cluster)");
        $self->update_status;

        for my $t (@tasks) {

            my ($workflow, $chunk, $runner) = @$t{qw(workflow chunk runner)};

            my $is_done = $workflow->is_complete;

            # If the state of the workflow indicates that it's
            # complete (based on the files that exist), we can
            # consider it done.
            if ($is_done) {
                $results[$chunk] = 1;
            }

            # If the job appears to be running or waiting on the
            # cluster, increment $still_running so we wait for it to
            # finish.
            elsif ($self->proc_ok($chunk)) {
                $log->info("Looks like chunk $chunk is running or waiting");
            }

            # Otherwise the task may have died for some reason, but it may just 
            # be that we had trouble checking the status. Give it
            # $NUM_CHECKS_BEFORE_RESTART chances before trying to start it
            # again.
            elsif (++$t->{not_ok_count} < $NUM_CHECKS_BEFORE_RESTART) {

                $log->info("Chunk $chunk is not running or waiting. ".
                           "I've checked on it $t->{not_ok_count} " .
                           ($t->{not_ok_count} == 1 ? "time" : "times") .
                           ". I'll give it a few more minutes. Details of " .
                           "job status:");
                $self->log_last_status_warning;
            }

            # If it reported a failed status $NUM_CHECKS_BEFORE_RESTART times 
            # in a row, go ahead and start again.
            elsif ($runner->run) {
                $log->warn("It seems like chunk $chunk is not running, so I started it again. This may mean that there was a temporary error on the machine that is running the chunk, and restarting it may fix it. If the job runs to completion and there are no other errors in the log file, everything is probably fine.");
                $self->log_last_status_warning;
                $t->{not_ok_count} = 0;
            }

            # If $runner->run returned false, that means we've restarted it too 
            # many times, so give up on it. Set it's @result value to to record
            # that we gave up on it.
            else {
                $log->error("There may be a serious problem with chunk $chunk. I have restarted it too many times, and it still does not seem to be running, so I am giving up on it.");
                $results[$chunk] = 0;
            }
        }

        # See if there are any chunks with non-zero results, meaning that we are
        # still waiting for them.
        my @waiting = grep { !defined } @results[@chunks];

        if (@waiting) {
            sleep $CLUSTER_CHECK_INTERVAL;
        }
        else {
            if ($status->outstanding_chunks) {
                $log->error("It looks like we've given up on all the chunks");
            }
            last;
        }
    }
    return \@results;
}

sub postprocess {
    my ($self) = @_;

    my $workflow = $self->postprocessing_workflow;
    my $run = sub { $self->submit_postproc };
    my $runner = RUM::WorkflowRunner->new($workflow, $run);
    $self->update_status;
    $runner->run;

    while (1) {

        sleep $CLUSTER_CHECK_INTERVAL;
        $self->update_status;

        if ($workflow->is_complete) {
            $log->debug("Postprocessing is done");
            return 1;
        }

        elsif ($self->postproc_ok) {
            $log->debug("Looks like postprocessing is running or waiting");
        }

        elsif ($runner->run) {
            $log->error("It seems like postprocessing has failed, so I am " .
                        "starting it again. It may be that there was a " .
                        "temporary error on the node running postprocessing, " .
                        "and restarting it may fix it. If the job runs to " .
                        "there are no completion and there are no ".
                        "subsequent errors in the log file, everything is " .
                        "probably fine.");
            $self->log_last_status_warning;
        }
        else {
            $log->error("Restarted postprocessing too many times; giving up");
            $log->debug("Postprocessing has failed");
            return 0;
        }

        $log->debug("Postprocessing is still running");

        sleep $CLUSTER_CHECK_INTERVAL;
    }

}

sub submit_preproc { croak "submit_preproc not implemented" }
sub submit_proc { croak "submit_proc not implemented" }
sub submit_postproc { croak "submit_postproc not implemented" }
sub update_status { croak "update_status not implemented" }
sub proc_ok { croak "proc_ok not implemented" }
sub postproc_ok { croak "postproc_ok not implemented" }
sub log_last_status_warning { }

1;

__END__

=head1 NAME

RUM::Platform::Cluster - Abstract base class for a platform that runs on a cluster

=head1 SYNOPSIS

=head1 DESCRIPTION

This attempts to provide an abstraction over platforms that are based
on a cluster. There is currently only one implementation:
L<RUM::Platform::SGE>.

=head1 OBJECT METHODS

=over 4

=item preprocess

Submits the preprocessing task.

=item process($chunk)

Submits the processing tasks, and periodically polls them to check
their status, attempting to restart any tasks that don't seem to be
running. If chunk is provided, I'll just do that chunk.

=item postprocess

Submits the postprocessing task, and periodically polls it to check on
its status, restarting it if it seems to have failed.

=back

=head2 Abstract Methods

=over 4

=item $platform->submit_preproc

=item $platform->submit_proc

=item $platform->submit_proc($chunk)

=item $platform->submit_postproc

Subclasses must implement these methods to submit the respective
tasks.

submit_preproc and submit_postproc will be called with no arguments.

submit_proc may be called with either no arguments or an optional
$chunk argument. If called with no arguments, the implementation
should submit all chunks. If called with a $chunk argument, the
implementation should submit only the job for that chunk.

=item $platform->update_status

A subclass should implement this so that it refreshes whatever data
structure it uses to store the status of its jobs.

=item $platform->proc_ok($chunk)

=item $platform->postproc_ok

A subclass should implement these methods so that they return a true
value if the processing or postprocessing phase (respectively) is in
an 'ok' state, where it is either running or waiting to be run.

=item $platform->log_last_status_warning

A subclass should implement this to log a message describing the last
status update it got from the underlying system.

=item $platform->stop

A subclass should implement this to attempt to stop a running job.
