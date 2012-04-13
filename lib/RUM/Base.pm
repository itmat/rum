package RUM::Base;

use strict;
use warnings;

use Text::Wrap qw(wrap fill);

sub new {
    my ($class, $config, $directives) = @_;
    my $self = {};
    $self->{config} = $config;
    $self->{directives} = $directives;
    bless $self, $class;
}

sub config { $_[0]->{config} }

sub directives { $_[0]->{directives} }

sub say {
    my ($self, @msg) = @_;
    #$log->info("@msg");
    print wrap("", "", @msg) . "\n" unless $self->directives->quiet;
}

1;
