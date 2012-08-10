package RUM::Sequence;

use strict;
use warnings;
use autodie;

use Carp;

use base 'RUM::Identifiable';

sub new {
    my ($class, %params) = @_;
    my $self = $class->SUPER::new(%params);
    $self->{seq}  = delete $params{seq} or croak "Need seq";
    $self->{qual} = delete $params{qual};
    return $self;
}

sub seq { $_[0]->{seq} }

sub qual { $_[0]->{qual} }

sub copy {
    my ($self, %params) = @_;
    my %copy = %{ $self };
    while (my ($k, $v) = each %params) {
        $copy{$k} = $v;
    }
    return __PACKAGE__->new(%copy);
}
1;
