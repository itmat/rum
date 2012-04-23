package RUM::Action::Kill;

=head1 NAME

RUM::Action::Kill - Kill a rum job

=head1 DESCRIPTION

Kills a running rum job.

=over 4

=cut

use strict;
use warnings;

use Getopt::Long;
use Text::Wrap qw(wrap fill);

use base 'RUM::Base';

=item run

Kill the job.

=cut

sub run {
    my ($class) = @_;

    my $self = $class->new;

    my $d = $self->{directives} = RUM::Directives->new;
    GetOptions(
        "o|output=s" => \(my $dir),
    );
    $dir or RUM::Usage->bad(
        "The --output or -o option is required for \"rum_runner kill\"");
    $self->{config} = RUM::Config->load($dir);
    $self->say("Killing job");
    $self->platform->stop;
    $RUM::Lock::FILE = $self->config->in_output_dir(".rum/lock");
    RUM::Lock->release;
}

1;

=back
