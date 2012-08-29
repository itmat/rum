package RUM::Action::Reset;

use strict;
use warnings;

use Carp;

use RUM::Action::Kill;
use RUM::Action::Clean;
use Data::Dumper;
use base 'RUM::Action';

sub new { shift->SUPER::new(name => 'reset', @_) }

sub run {
    my ($class) = @_;
    my $self = $class->new;
    
    my $config = $self->{config} = RUM::Config->new->parse_command_line(
        options => [qw(output_dir step)],
        load_default => 1
    );
    $self->{workflows} = RUM::Workflows->new($self->config);

    my $workflows = $self->{workflows};

    my $wanted_step = $config->step || 0;

    my $processing_steps;
    
    for my $chunk (1 .. $config->chunks) {
        my $workflow = $workflows->chunk_workflow($chunk);
        $processing_steps = $self->reset_workflow($workflow, $wanted_step);
    }

    $self->reset_workflow($workflows->postprocessing_workflow, $wanted_step - $processing_steps);
}

sub reset_workflow {
    my ($self, $workflow, $wanted_step) = @_;

    my %keep;
    my $plan = $workflow->state_machine->plan or croak "Can't build a plan";
    my @plan = @{ $plan };
    my $state = $workflow->state_machine->start;
    my $step = 0;
    for my $e (@plan) {
        $step++;
        $state = $workflow->state_machine->transition($state, $e);
        if ($step <= $wanted_step) {
            for my $file ($state->flags) {
                $keep{$file} = 1;
            }
        }
        
    }
    
    my @remove = grep { !$keep{$_} } $state->flags;
    
    unlink @remove;
    return $step;
}


1;

__END__

=head1 NAME

RUM::Action::Reset - Kill a rum job and remove all of its output

=head1 DESCRIPTION

Kills a job if it's running, and removes all of its output files.

=over 4

=item run

Reset the job.

=cut

=back
