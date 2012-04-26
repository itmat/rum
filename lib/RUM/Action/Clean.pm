package RUM::Action::Clean;

=head1 NAME

RUM::Action::Clean - Clean up temp files from a rum job

=head1 METHODS

=over 4

=cut

use strict;
use warnings;

use Carp;
use Getopt::Long;
use File::Path qw(rmtree);
use Text::Wrap qw(wrap fill);
use base 'RUM::Base';

=item run

Run the action: parse @ARGV, cleanup temp files.

=cut

sub run {
    my ($class) = @_;

    my $self = $class->new;

    GetOptions(
        "o|output=s" => \(my $dir),
        "very"         => \(my $very)
    );
    $dir or RUM::Usage->bad(
        "The --output or -o option is required for \"rum_runner align\"");
    $self->{config} = RUM::Config->load($dir) or croak 
        "$dir doesn't seem to be a rum output directory";
    $self->clean($very);
}


=item cleanup_reads_and_quals

Remove all the reads.fa.* and quals.fa.* files. The preprocessing step
(which produces these files) isn't yet modeled as a RUM::Workflow, so
we can't use its clean method on these files.

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
    my ($self, $very) = @_;
    my $c = $self->config;

    local $_;
    my @dirs = ($c->chunk_dir, $c->temp_dir, $c->postproc_dir);

    if ($very) {
        push @dirs, $c->in_output_dir("log");
        RUM::Workflows->postprocessing_workflow($c)->clean(1);
    }
    rmtree(\@dirs);
}

1;

=back
