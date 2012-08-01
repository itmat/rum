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
use File::Find;
use base 'RUM::Base';

=item run

Run the action: parse @ARGV, cleanup temp files.

=cut

sub run {
    my ($class) = @_;

    my $self = $class->new;
    my $usage = RUM::Usage->new(action => 'clean');

    GetOptions(
        "o|output=s" => \(my $dir),
        "very"         => \(my $very),
        "help|h" => sub { $usage->help }
    );
    $dir or $usage->bad(
        "The --output or -o option is required for \"rum_runner align\"");
    $usage->check;
    $self->{config} = RUM::Config->load($dir, 1);
    $self->clean($very);
}


=item clean

Remove intermediate files.

=cut

sub clean {
    my ($self, $very) = @_;
    my $c = $self->config;

    local $_;

    # Remove any temporary files (those that end with .tmp.XXXXXXXX)
    find sub {
        if (/\.tmp\.........$/) {
            unlink $File::Find::name;
        }
    }, $c->output_dir;

    # Make a list of dirs to remove
    my @dirs = ($c->chunk_dir, $c->temp_dir, $c->postproc_dir);

    # If we're doing a --very clean, also remove the log directory and
    # the final output.
    if ($very) {
        push @dirs, $c->in_output_dir("log");
        RUM::Workflows->new($c)->postprocessing_workflow->clean(1);
        unlink($self->config->in_output_dir("quals.fa"),
               $self->config->in_output_dir("reads.fa"));
        $self->say("Destroying job settings file");
        $self->config->destroy;
    }

    rmtree(\@dirs);
}

1;

=back
