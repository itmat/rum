package RUM::Action::Status;

=head1 NAME

RUM::Action::Status - Print status of job

=head1 METHODS

=over 4

=cut

use strict;
use warnings;

use Text::Wrap qw(wrap fill);
use Carp;
use RUM::Action::Help;
use base 'RUM::Action';

=item run

Run the action.

=cut

sub run {
    my ($class) = @_;

    my $self = $class->new(name => 'status');
    $self->get_options;

    if ( ! $self->{loaded_config} ) {
        $self->say("There does not seem to be a RUM job in "
                   . $self->config->output_dir);
        return;
    }

    $self->{workflows} = RUM::Workflows->new($self->config);

    $self->print_processing_status;
    $self->print_postprocessing_status;
    $self->say();
    $self->_chunk_error_logs_are_empty;

    $self->say("");
    $self->platform->show_running_status;

    my $postproc = $self->{workflows}->postprocessing_workflow;
    if ($postproc->is_complete) {
        $self->say("");
        $self->say("RUM Finished.");
    }
}

=item print_processing_status

Print the status for all the steps of the "processing" phase.

=cut

sub print_processing_status {
    my ($self) = @_;

    local $_;
    my $c = $self->config;

    my @chunks = $self->chunk_nums;

    my @errored_chunks;
    my @progress;
    my $workflows = $self->{workflows};

    my $workflow = $workflows->chunk_workflow(1);
    my $plan = $workflow->state_machine->plan or croak "Can't build a plan";
    my @plan = @{ $plan };
    my $postproc = $workflows->postprocessing_workflow($c);
    my $postproc_started = $postproc->steps_done;

    for my $chunk (@chunks) {
        my $w = $workflows->chunk_workflow($chunk);
        my $m = $w->state_machine;
        my $state = $w->state;
        $m->recognize($plan, $state) 
            or croak "Plan doesn't work for chunk $chunk";

        my $skip = $m->skippable($plan, $state);

        $skip = @plan if $postproc_started;

        for (0 .. $#plan) {
            $progress[$_] .= ($_ < $skip ? "X" : " ");
        }
    }

    my $n = @chunks;

    $self->say("Processing in $n chunks");
    $self->say("-----------------------");

    for (0 .. $#plan) {
        my $progress = $progress[$_] . " ";
        my $comment   = $workflow->comment($plan[$_]);
        my $indent = ' ' x length($progress);
        $self->say(wrap($progress, $indent, $comment));
    }

    print "\n" if @errored_chunks;
    for my $line (@errored_chunks) {
        warn "$line\n";
    }

}

=item print_postprocessing_status

Print the status of all the steps of the "postprocessing" phase.

=cut

sub print_postprocessing_status {
    my ($self) = @_;
    local $_;
    my $c = $self->config;

    $self->say();
    $self->say("Postprocessing");
    $self->say("--------------");

    my $postproc = $self->{workflows}->postprocessing_workflow($c);

    my $state = $postproc->state;
    my $plan = $postproc->state_machine->plan or croak "Can't build plan";
    my @plan = @{ $plan };
    my $skip = $postproc->state_machine->skippable($plan, $state);
    for (0 .. $#plan) {
        my $progress = $_ < $skip ? "X" : " ";
        my $comment  = $postproc->comment($plan[$_]);
        $self->say("$progress $comment");
    };
}

1;

=back
