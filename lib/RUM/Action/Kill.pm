package RUM::Action::Kill;

use strict;
use warnings;

use Getopt::Long;
use Text::Wrap qw(wrap fill);
use RUM::Action::Clean;
use base 'RUM::Base';

sub run {
    my ($class) = @_;

    my $self = $class->new;
    my $d = $self->{directives} = RUM::Directives->new;
    my $usage = RUM::Usage->new(action => 'kill');

    GetOptions(
        "o|output=s" => \(my $dir),
        "help|h"     => sub { $usage->help }
    );
    $dir or $usage->bad(
        "The --output or -o option is required for \"rum_runner kill\"");
    $usage->check;
    $self->{config} = RUM::Config->load($dir, 1);
    $self->say("Stopping job");
    $self->platform->stop;

    $self->say("Cleaning up output files");
    RUM::Action::Clean->new($self->config)->clean(1);
    $RUM::Lock::FILE = $self->config->in_output_dir(".rum/lock");
    RUM::Lock->release;

}

1;

__END__

=head1 NAME

RUM::Action::Kill - Kill a rum job

=head1 DESCRIPTION

Kills a running rum job.

=over 4

=item run

Kill the job.

=cut

=back
