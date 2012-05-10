package RUM::Alignment;

use strict;
use warnings;

use Carp;

sub new {
    my ($class, %params) = @_;
    my $self = {};
    $self->{readid} = delete $params{-readid} or croak "Need -readid";
    $self->{chr}    = delete $params{-chr} or croak "Need -readid";
    $self->{locs}   = delete $params{-locs} or croak "Need -locs";
    $self->{strand} = delete $params{-strand} or croak "Need -strand";
    $self->{seq}    = delete $params{-seq} or croak "Need -strand";
    return bless $self, $class;
}

sub readid     { $_[0]->{readid} }
sub chromosome { $_[0]->{chr} }
sub locs       { $_[0]->{locs} }
sub strand     { $_[0]->{strand} }
sub seq        { $_[0]->{seq} }
sub is_forward { 
    my $self = shift;
    local $_ = $self->readid;
    /seq\.\d+(a|b)/ or croak "Can't determine direction for $_";
    return $1 eq 'a';
}
sub is_reverse { ! $_[0]->is_forward }
1;
