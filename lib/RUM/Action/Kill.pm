package RUM::Action::Kill;

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
    );

    $self->{config} = RUM::Config->load($dir);
    $self->say("Killing job");
    $self->platform->stop;
}

1;
