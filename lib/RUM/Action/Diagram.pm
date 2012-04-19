package RUM::Action::Diagram;

=head1 NAME

RUM::Action::Diagram - Create a diagram of the workflow. EXPERIMENTAL!

=head1 DESCRIPTION

Creates a dotty diagram of the workflow. Doesn't really work too well;
just useful for development debugging purposes.

=over 4

=cut

use strict;
use warnings;

use Getopt::Long;
use Text::Wrap qw(wrap fill);

use base 'RUM::Base';

=item run

Run the action parsing the command-line options and, creating the
diagram.

=cut

sub run {
    my ($class) = @_;

    my $self = $class->new;

    my $d = $self->{directives} = RUM::Directives->new;

    GetOptions(
        "o|output=s" => \(my $dir = "."),
    );

    $self->{config} = RUM::Config->load($dir);
    $self->diagram;
}

=item diagram

Actually create the diagram.

=cut

sub diagram {
    my ($self) = @_;

    print "My num chunks is ", $self->config->num_chunks, "\n";
    my $d = $self->directives;
    if ($d->process || $d->all) {
        for my $chunk ($self->chunk_nums) {
            my $dot = $self->config->in_output_dir(sprintf("chunk%03d.dot", $chunk));
            my $pdf = $self->config->in_output_dir(sprintf("chunk%03d.pdf", $chunk));
            open my $dot_out, ">", $dot;
            RUM::Workflows->chunk_workflow($self->config->for_chunk($chunk))->state_machine->dotty($dot_out);
            close $dot_out;
            system("dot -o$pdf -Tpdf $dot");
        }
    }

    if ($d->postprocess || $d->all) {
        my $dot = $self->config->in_output_dir("postprocessing.dot");
        my $pdf = $self->config->in_output_dir("postprocessing.pdf");
        open my $dot_out, ">", $dot;
        RUM::Workflows->postprocessing_workflow($self->config)->state_machine->dotty($dot_out);
        close $dot_out;
        system("dot -o$pdf -Tpdf $dot");
    }
}

1;

=back
