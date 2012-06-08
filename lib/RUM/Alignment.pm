package RUM::Alignment;

use strict;
use warnings;

use Carp;

sub new {
    my ($class, %params) = @_;
    my $self = {};

    local $_;
    for (qw(readid chr strand seq)) {
        defined($self->{$_} = delete $params{$_}) or croak "Need $_";
    }

    defined($self->{locs}   = delete $params{locs})
    or defined($self->{loc}   = delete $params{loc})
    or croak "Need locs or loc";

    return bless $self, $class;
}

sub copy {
    my ($self, %params) = @_;
    my %copy = %{ $self };
    while (my ($k, $v) = each %params) {
        $copy{$k} = $v;
    }
    return __PACKAGE__->new(%copy);
}

sub readid     { $_[0]->{readid} }
sub chromosome { $_[0]->{chr} } 
sub locs       { $_[0]->{locs} }
sub loc        { $_[0]->{loc} } 
sub strand     { $_[0]->{strand} }
sub seq        { $_[0]->{seq} } 
sub starts     { [ map { $_->[0] } @{ $_[0]->{locs} } ] }

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
    
    my $other_dir = $dir eq 'a' ? 'b' : 'a';
    return $other->readid eq "$num$other_dir";
}



1;
