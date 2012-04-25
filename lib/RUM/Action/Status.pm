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
use base 'RUM::Base';

=item run

Run the action.

=cut

sub run {
    my ($class) = @_;

    my $self = $class->new;

    my $d = $self->{directives} = RUM::Directives->new;

    GetOptions(
        "o|output=s" => \(my $dir),
        "preprocess"   => sub { $d->set_preprocess;  $d->unset_all; },
        "process"      => sub { $d->set_process;     $d->unset_all; },
        "postprocess"  => sub { $d->set_postprocess; $d->unset_all; },
        "chunk=s"      => \(my $chunk),
    );
    $dir or RUM::Usage->bad(
        "The --output or -o option is required for \"rum_runner align\"");
    $self->{config} = RUM::Config->load($dir);
    $self->print_processing_status if $d->process || $d->all;
    $self->print_postprocessing_status if $d->postprocess || $d->all;
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

    my @chunks = $c->chunk ? ($c->chunk) : $self->chunk_nums;

    my @errored_chunks;
    my @progress;
    my $workflow = RUM::Workflows->chunk_workflow($c->for_chunk(1));
    my $plan = $workflow->state_machine->plan or croak "Can't build a plan";
    my @plan = @{ $plan };


    for my $chunk (@chunks) {
        my $config = $c->for_chunk($chunk);
        my $w = RUM::Workflows->chunk_workflow($config);
        my $m = $w->state_machine;
        my $state = $w->state;
        $m->recognize($plan, $state) 
            or croak "Plan doesn't work for chunk $chunk";

        my $skip = $m->skippable($plan, $state);

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
