package RUM::Action::Clean;

=head1 NAME

RUM::Action::Clean - Clean up temp files from a rum job

=head1 METHODS

=over 4

=cut

use strict;
use warnings;

use Getopt::Long;
use Text::Wrap qw(wrap fill);
use base 'RUM::Base';

=item run

Run the action: parse @ARGV, cleanup temp files.

=cut

sub run {
    my ($class) = @_;

    my $self = $class->new;

    my $d = $self->{directives} = RUM::Directives->new;

    GetOptions(
        "o|output=s" => \(my $dir = "."),
        "preprocess"   => sub { $d->set_preprocess;  $d->unset_all; },
        "process"      => sub { $d->set_process;     $d->unset_all; },
        "postprocess"  => sub { $d->set_postprocess; $d->unset_all; },
        "very"         => sub { $d->set_veryclean; },
        "chunk=s"      => \(my $chunk),
    );

    $self->{config} = RUM::Config->load($dir);
    $self->clean;
}


=item cleanup_reads_and_quals

Remove all the reads.fa.* and quals.fa.* files. The preprocessing step
(which produces these files) isn't yet modeled as a RUM::Workflow, so
we can't us its clean method on these files.

=cut

sub cleanup_reads_and_quals {
    my ($self) = @_;
    for my $chunk ($self->chunk_nums) {
        my $c = $self->config->for_chunk($chunk);
        unlink($c->chunk_suffixed("quals.fa"),
               $c->chunk_suffixed("reads.fa"));
    }

}

=item clean

Remove intermediate files.

=cut

sub clean {
    my ($self) = @_;
    my $c = $self->config;
    my $d = $self->directives;
    my $dir = $c->output_dir;

    # If user ran rum_runner --clean, clean up all the results from
    # the chunks; just leave the merged files.
    if ($d->all) {
        $self->cleanup_reads_and_quals;
        for my $chunk ($self->chunk_nums) {
            my $w = RUM::Workflows->chunk_workflow($c->for_chunk($chunk));
            $w->clean(1);
        }
        RUM::Workflows->postprocessing_workflow($c)->clean($d->veryclean);
    }

    # Otherwise just clean up whichever phases they asked
    elsif ($d->preprocess) {
        $self->cleanup_reads_and_quals;
    }

    # Otherwise just clean up whichever phases they asked
    elsif ($d->process) {
        for my $w ($self->chunk_workflows) {
            $w->clean($d->veryclean);
        }
    }

    if ($d->postprocess) {
        RUM::Workflows->postprocessing_workflow($c)->clean($d->veryclean);
    }

    if ($d->veryclean) {
        system "rm -f $dir/_tmp_* $dir/*.log $dir/rum.error-log";
    }
}

1;

=back
