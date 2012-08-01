package RUM::Action::Clean;

use strict;
use warnings;

use Getopt::Long;
use File::Path qw(rmtree);
use File::Find;
use base 'RUM::Action';

sub run {
    my ($class) = @_;

    my $self = $class->new(name => 'clean');
    $self->get_options('--very' => \(my $very));
    $self->check_usage;
    $self->clean($very);
}

sub clean {
    my ($self, $very) = @_;
    my $c = $self->config;

    local $_;

    # Remove any temporary files (those that end with .tmp.XXXXXXXX)
    $self->logsay("Removing files");
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

__END__

=head1 NAME

RUM::Action::Clean - Clean up temp files from a rum job

=head1 METHODS

=over 4

=item run

Run the action: parse @ARGV, cleanup temp files.


=item clean

Remove intermediate files.

=cut

=back
