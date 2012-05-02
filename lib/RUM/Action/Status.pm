package RUM::Action::Status;

=head1 NAME

RUM::Action::Status - Print status of job

=head1 METHODS

=over 4

=cut

use strict;
use warnings;

use Getopt::Long;
use Text::Wrap qw(wrap fill);
use Carp;
use RUM::Action::Help;
use base 'RUM::Base';

=item run

Run the action.

=cut

sub run {
    my ($class) = @_;

    my $self = $class->new;

    my $d = $self->{directives} = RUM::Directives->new;

    my $usage = RUM::Usage->new(action => 'status');

    GetOptions(
        "o|output=s" => \(my $dir),
        "h|help" => sub { $usage->help }
    );

    $dir or $usage->bad(
        "The --output or -o option is required for \"rum_runner status\"");
    $usage->check;
    $self->{config} = RUM::Config->load($dir, 1);
    $self->print_processing_status;
    $self->print_postprocessing_status;
    $self->say();
    $self->_chunk_error_logs_are_empty;
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
    my $workflow = RUM::Workflows->chunk_workflow($c, 1);
    my $plan = $workflow->state_machine->plan or croak "Can't build a plan";
    my @plan = @{ $plan };

    my $postproc = RUM::Workflows->postprocessing_workflow($c);
    my $postproc_started = $postproc->steps_done;

    for my $chunk (@chunks) {
        my $w = RUM::Workflows->chunk_workflow($c, $chunk);
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

    my $postproc = RUM::Workflows->postprocessing_workflow($c);

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
