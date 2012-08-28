package RUM::JobStatus;

=head1 NAME

RUM::JobStatus - API for getting the status of a job

=head1 SYNOPSIS

  my $status = RUM::JobStatus->new($config);
  my @chunk_ids = $status->outstanding_chunks;

=head1 OBJECT METHODS

=over 4

=cut

use strict;
use warnings;
use autodie;

use base 'RUM::Base';

=item $js->processing_workflow($chunk)

Return the workflow for the specified chunk.

=item $js->postprocessing_workflow

Return the postprocessing workflow.

=item $js->outstanding_chunks

Return a list of the chunk ids that are not yet done.

=cut

sub postprocessing_workflow {
    my ($self) = @_;
    return $self->workflows->postprocessing_workflow;
}

sub processing_workflow {
    my ($self, $chunk) = @_;
    return $self->workflows->chunk_workflow($chunk);
}

sub outstanding_chunks {
    my ($self) = @_;

    # If we've started postprocessing, then the processing phase must
    # be complete
    if ($self->postprocessing_workflow->steps_done) {
        return ();
    }

    my @chunks = (1 .. $self->config->chunks);

    return grep { ! $self->processing_workflow($_)->is_complete } @chunks;
}

1;

=back

=cut
