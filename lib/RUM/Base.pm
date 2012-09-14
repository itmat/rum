package RUM::Base;

=head1 NAME

RUM::Base - Base class for a few RUM classes

=head1 SYNOPSIS

  use base 'RUM::Base';

  ...

  my $config = $self->config;
  my @reads = $self->reads;
  $self->say("Message to user");
  my @chunks = $self->chunk_nums;

=head1 DESCRIPTION

Provides a few methods that are commonly used by RUM::Runner and
RUM::Platform and its subclasses; basically any class that needs
access to the RUM::Config for the job.

=cut

use strict;
use warnings;

use Carp;
use Text::Wrap qw(wrap fill);

use RUM::Logging;
use RUM::Workflows;
use RUM::JobReport;

our $log = RUM::Logging->get_logger();

=head1 CONSTRUCTOR

=over 4

=item new($config)

Subclasses that defined a I<new> method should call me in the
constructor before doing anything else.

=back

=cut

sub new {
    my ($class, $config) = @_;

    croak "Can't call RUM::Base->new on $class" if ref($class);
    my $self = {};
    $self->{config} = $config; # or croak        "$class->new called without config";
    bless $self, $class;
}

=head1 METHODS

=over 4

=cut


=item config

Return the config for this RUM job.

=cut

sub config { $_[0]->{config} }

=item say(@msg)

Print a message to the user, wrapping long lines.

=cut

sub say {
    my ($self, @msg) = @_;
    if (!@msg) {
        @msg = ("");
    }
    print wrap("", "", @msg) . "\n" unless $self->config && $self->config->quiet;
}

=item logsay(@msg)

Print @msg to the screen (unless I'm in quiet mode) and log it at the
info level.

=cut

sub logsay {
    my ($self, @msg) = @_;
    $self->say(@msg);
    my $package;
    ref($self) =~ /(.*)=/ and $package = $1;
    RUM::Logging->get_logger($package)->info(@msg);
}

=item alert(@msg)

Log @msg at the warning level.

=cut

sub alert {
    my ($self, @msg) = @_;
    $self->say(@msg);
    my $package;
    ref($self) =~ /(.*)=/ and $package = $1;
    RUM::Logging->get_logger($package)->warn(@msg);
}



=item chunk_nums

Return a list of chunk numbers I'm supposed to process, which is a
single number if I was run with a --chunk option, or all of the chunks
from 1 to $n otherwise.

=cut

sub chunk_nums {
    my ($self) = @_;
    return (1 .. $self->config->chunks || 1)
}

=item platform

Return the platform that this job is configured to run on.

=cut

sub platform {
    my ($self) = @_;

    my $name = $self->config->child ? "Local" : $self->config->platform;
    my $class = "RUM::Platform::$name";
    my $file = "RUM/Platform/$name.pm";

    require $file;
    my $platform = $class->new($self->config);
}

sub _chunk_error_logs_are_empty {
    my ($self) = @_;
    my $c = $self->config;
    my $dir = File::Spec->catfile($c->output_dir, "log");
    my @errors;
    for my $chunk ($self->chunk_nums) {
        my $log_file = File::Spec->catfile(
            $dir, sprintf("rum_errors_%d.log", $chunk));
        if (-s $log_file) {
            push @errors, "Chunk $chunk had errors, please check $log_file";
        }
    }

    my $log_file = File::Spec->catfile($dir, "rum_errors.log");
    if (-s $log_file) {
        push @errors, "Main log file had errors, please check $log_file";
    }

    $log_file = File::Spec->catfile($dir, "rum_errors_postproc.log");
    if (-s $log_file) {
        push @errors, "Postprocessing log file had errors, please check $log_file";
    }

    if (@errors) {
        for my $error (@errors) {
            $self->alert("!!! $error");
        }
        return 1;
    }
    else {
        $self->say("All error log files are empty. That's good.");
        return 1;
    }

    return 0;
}

=item still_processing

Return a true value if we have started postprocessing or if at least
one of my chunks is still processing.

=cut

sub still_processing {
    my ($self) = @_;

    my $config = $self->config;

    my $workflows = RUM::Workflows->new($config);

    # If postprocessing has started, then we can't be in the
    # processing phase
    if ($workflows->postprocessing_workflow->steps_done) {
        return 0;
    }

    for my $chunk ( 1 .. $config->chunks ) {
        return 1 unless $workflows->chunk_workflow($chunk)->is_complete;
    }
    return 0;
}

=item $self->workflows

Return a RUM::Workflows object based on my configuration.

=cut

sub workflows {
    my ($self) = @_;
    $self->{workflows} ||= RUM::Workflows->new($self->config);
}

=item $self->chunk_workflow($chunk)

Return the workflow for the given chunk, based on my configuration.

=cut

sub chunk_workflow {
    my ($self, $chunk) = @_;
    return $self->workflows->chunk_workflow($chunk);
}

=item $self->postprocessing_workflow

Return the workflow for the postprocessing step, based on my configuration.

=cut

sub postprocessing_workflow {
    my ($self) = @_;
    return $self->workflows->postprocessing_workflow;
}

=back

=cut

1;
