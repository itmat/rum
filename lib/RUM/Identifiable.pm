package RUM::Identifiable;

use strict;
use warnings;
use autodie;

use Carp;

sub new {
    my ($class, %params) = @_;
    my $self = {};
    $self->{readid} = delete $params{readid};
    return bless $self, $class;
}

sub readid     { $_[0]->{readid} }

sub is_forward { 
    shift->_direction eq 'a';
}

sub is_reverse { 
    shift->_direction eq 'b';
}

sub contains_forward {
    shift->_direction ne 'b';
}

sub contains_reverse {
    shift->_direction ne 'a';
}

sub _direction {
    local $_ = shift->readid;
    if (/^seq\.\d+([ab]?)$/) {
        return $1;
    }
    else {
        warn "Misformatted read id $_\n";
        return;
    }
}

sub readid_directionless {
    my ($self) = @_;
    local $_ = $self->readid;
    s/(a|b)$//;
    return $_;
}

sub is_same_read {
    my ($self, $other) = @_;
    return $self->readid eq $other->readid;
}

sub is_mate {

    my ($self, $other) = @_;
    local $_ = $self->readid;
    /(seq\.\d+)(a|b)/ or croak "Can't determine direction for $_";
    my ($num, $dir) = ($1, $2);
    
    my $other_dir = $dir eq 'a' ? 'b' : 'a';
    return $other->readid eq "$num$other_dir";
}

1;
