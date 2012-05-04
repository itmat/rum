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
    my $usage = RUM::Usage->new(action => 'kill');

    GetOptions(
        "o|output=s" => \(my $dir),
        "help|h" => sub { $usage->help }
    );
    $dir or $usage->bad(
        "The --output or -o option is required for \"rum_runner kill\"");
    $usage->check;
    $self->{config} = RUM::Config->load($dir, 1);
    $self->say("Killing job");
    $self->platform->stop;
    $RUM::Lock::FILE = $self->config->in_output_dir(".rum/lock");
    RUM::Lock->release;
}

1;

=back
