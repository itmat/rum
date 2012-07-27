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

sub readid { $_[0]->{readid} }

sub order {
    my ($self) = @_;
    $self->readid =~ /seq.(\d+)/ and return $1;
}

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
        warn "Misformatted read id '$_'\n";
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
    return unless $other;
    local $_ = $self->readid;
    /(seq\.\d+)(a|b)/ or return 0;
    my ($num, $dir) = ($1, $2);
    
    my $other_dir = $dir eq 'a' ? 'b' : 'a';
    return $other->readid eq "$num$other_dir";
}

sub is_same_or_mate {
    my ($x, $y) = @_;
    return $x->is_same_read($y) || $x->is_mate($y);
}


sub cmp_read_ids {
    my ($self, $other) = @_;
    my ($self_num)  = $self->readid  =~ /seq\.(\d+)/g;
    my ($other_num) = $other->readid =~ /seq\.(\d+)/g;
    return $self_num <=> $other_num;
}



1;
