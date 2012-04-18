package RUM::Action::Status;

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
        "chunk=s"      => \(my $chunk),
    );

    $self->{config} = RUM::Config->load($dir);
    $self->print_processing_status if $d->process || $d->all;
    $self->print_postprocessing_status if $d->postprocess || $d->all;
}

sub print_processing_status {
    my ($self) = @_;

    local $_;
    my $c = $self->config;

    my @steps;
    my %num_completed;
    my %comments;
    my %progress;
    my @chunks;

    if ($c->chunk) {
        push @chunks, $c->chunk;
    }
    else {
        push @chunks, (1 .. $c->num_chunks || 1);
    }

    for my $chunk (@chunks) {
        my $w = RUM::Workflows->chunk_workflow($c->for_chunk($chunk));
        my $handle_state = sub {
            my ($name, $completed) = @_;
            unless (exists $num_completed{$name}) {
                $num_completed{$name} = 0;
                $progress{$name} = "";
                $comments{$name} = $w->comment($name);
                push @steps, $name;
            }
            $progress{$name} .= $completed ? "X" : " ";
            $num_completed{$name} += $completed;
        };

        $w->walk_states($handle_state);
    }

    my $n = @chunks;
    #my $digits = num_digits($n);
    #my $h1     = "   Chunks ";
    #my $h2     = "Done / Total";
    #my $format =  "%4d /  %4d ";

    $self->say("Processing in $n chunks");
    $self->say("-----------------------");
    #$self->say($h1);
    #$self->say($h2);
    for (@steps) {
        #my $progress = sprintf $format, $num_completed{$_}, $n;
        my $progress = $progress{$_} . " ";
        my $comment   = $comments{$_};
        my $indent = ' ' x length($progress);
        $self->say(wrap($progress, $indent, $comment));
    }

}

sub print_postprocessing_status {
    my ($self) = @_;
    my $c = $self->config;

    $self->say();
    $self->say("Postprocessing");
    $self->say("--------------");
    my $postproc = RUM::Workflows->postprocessing_workflow($c);
    my $handle_state = sub {
        my ($name, $completed) = @_;
        $self->say(($completed ? "X" : " ") . " " . $postproc->comment($name));
    };
    $postproc->walk_states($handle_state);
}

1;
