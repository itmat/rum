package RUM::Action::Clean;

use strict;
use warnings;

use Getopt::Long;
use Text::Wrap qw(wrap fill);

use base 'RUM::Base';

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


sub cleanup_reads_and_quals {
    my ($self) = @_;
    for my $chunk ($self->chunk_nums) {
        my $c = $self->config->for_chunk($chunk);
        unlink($c->chunk_suffixed("quals.fa"),
               $c->chunk_suffixed("reads.fa"));
    }

}

sub clean {
    my ($self) = @_;
    my $c = $self->config;
    my $d = $self->directives;

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
}

1;
