package RUM::Alignment;

use strict;
use warnings;

use Carp;

sub new {
    my ($class, %params) = @_;
    my $self = {};
    $self->{readid} = delete $params{-readid} or croak "Need -readid";
    $self->{chr}    = delete $params{-chr} or croak "Need -readid";
    $self->{locs}   = delete $params{-locs} or
    $self->{loc}   = delete $params{-loc} or
        croak "Need -locs or -loc";
    $self->{strand} = delete $params{-strand} or croak "Need -strand";
    $self->{seq}    = delete $params{-seq} or croak "Need -strand";
    return bless $self, $class;
}

sub readid     { $_[0]->{readid} }
sub chromosome { $_[0]->{chr} }
sub locs       { $_[0]->{locs} }
sub loc        { $_[0]->{loc} }
sub strand     { $_[0]->{strand} }
sub seq        { $_[0]->{seq} }
sub is_forward { 
    my $self = shift;
    local $_ = $self->readid;
    /seq\.\d+(a|b)/ or croak "Can't determine direction for $_";
    return $1 eq 'a';
}
sub is_reverse { ! $_[0]->is_forward }


sub is_same_read {
    my ($self, $other) = @_;
    return $self->readid eq $other->readid;
}

sub is_mate {

    my ($self, $other) = @_;
    local $_ = $self->readid;
    /(seq\.\d+)(a|b)/ or croak "Can't determine direction for $_";
    my ($num, $dir) = ($1, $2);
    
    my $other_dir = $1 eq 'a' ? 'b' : 'a';
    return $other->readid eq "$num$other_dir";
}


1;
