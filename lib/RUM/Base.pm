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

sub reads {
    return @{ $_[0]->config->reads };
}


sub say {
    my ($self, @msg) = @_;
    #$log->info("@msg");
    print wrap("", "", @msg) . "\n" unless $self->directives->quiet;
}

=item chunk_nums

Return a list of chunk numbers I'm supposed to process, which is a
single number if I was run with a --chunk option, or all of the chunks
from 1 to $n otherwise.

=cut

sub chunk_nums {
    my ($self) = @_;
    my $c = $self->config;
    if ($c->chunk) {
        return ($c->chunk);
    }
    return (1 .. $c->num_chunks || 1)
}



1;
